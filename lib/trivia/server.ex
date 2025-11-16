defmodule Trivia.Servidor do
  @moduledoc """
  Fachada del sistema de trivia.

  Se encarga de:
    * Conectar / autenticar usuarios.
    * Crear y gestionar partidas mediante el SupervisorDePartidas.
    * Delegar acciones a Trivia.Partida.

  También contiene el módulo Trivia.Servidor.Consola,
  que implementa el menú interactivo en la terminal (local o distribuido).
  """

  alias Trivia.{GestorDeUsuarios, SupervisorDePartidas, Partida, Ranking}

  def conectar_usuario(nombre_usuario, contrasena) do
    case GestorDeUsuarios.registrar_o_ingresar(nombre_usuario, contrasena) do
      {:registrado, _informacion_usuario} ->
        Agent.update(Trivia.SesionDeUsuario, fn sesiones ->
          Map.put(sesiones, nombre_usuario, %{conectado: true})
        end)

        {:ok, :registrado}

      {:ingresado, _informacion_usuario} ->
        Agent.update(Trivia.SesionDeUsuario, fn sesiones ->
          Map.put(sesiones, nombre_usuario, %{conectado: true})
        end)

        {:ok, :ingresado}

      {:error, :contrasena_invalida} ->
        {:error, :contrasena_invalida}
    end
  end

  def crear_partida(nombre_creador, categoria, opciones \\ []) do
    identificador_partida = System.unique_integer([:positive])

    argumentos_partida =
      Keyword.merge(opciones,
        identificador: identificador_partida,
        categoria: categoria,
        creador: nombre_creador
      )

    case SupervisorDePartidas.iniciar_partida(argumentos_partida) do
      {:ok, identificador_proceso_partida} ->
        # El creador queda registrado como jugador de la partida
        _ = Partida.unirse(identificador_proceso_partida, nombre_creador)

        {:ok, identificador_proceso_partida}

      otra_respuesta ->
        otra_respuesta
    end
  end

  def listar_partidas do
    SupervisorDePartidas.listar_pids_activos()
    |> Enum.map(fn identificador_proceso_partida ->
      Partida.obtener_resumen(identificador_proceso_partida)
    end)
  end

  def unirse_a_partida_por_id(identificador_busqueda, nombre_usuario) do
    SupervisorDePartidas.listar_pids_activos()
    |> Enum.find(fn identificador_proceso_partida ->
      %{identificador: identificador_partida} =
        Partida.obtener_resumen(identificador_proceso_partida)

      identificador_partida == identificador_busqueda
    end)
    |> case do
      nil ->
        {:error, :no_encontrada}

      identificador_proceso_partida ->
        case Partida.unirse(identificador_proceso_partida, nombre_usuario) do
          {:ok, :unido} ->
            {:ok, :unido, identificador_proceso_partida}

          {:ok, :ya_estaba} ->
            {:ok, :ya_estaba, identificador_proceso_partida}

          {:error, motivo} ->
            {:error, motivo}
        end
    end
  end

  def iniciar_partida(identificador_proceso_partida, nombre_creador) do
    Partida.iniciar(identificador_proceso_partida, nombre_creador)
  end

  def responder_pregunta(identificador_proceso_partida, nombre_usuario, opcion_letra) do
    Partida.responder(identificador_proceso_partida, nombre_usuario, opcion_letra)
  end

  def obtener_pregunta_actual(identificador_proceso_partida) do
    Partida.obtener_pregunta_actual(identificador_proceso_partida)
  end

  def puntaje_usuario(nombre_usuario) do
    GestorDeUsuarios.puntaje_propio(nombre_usuario)
  end

  def ranking_global do
    GestorDeUsuarios.ranking_global()
  end


  def ranking_por_tema(categoria) do
    Ranking.ranking_por_tema(categoria)
  end


  def obtener_resumen_partida(identificador_proceso_partida) do
    Partida.obtener_resumen(identificador_proceso_partida)
  end



  defmodule Consola do

    alias Trivia.Servidor



    def inicio do
      IO.puts("\n— TRIVIA 🎮  (TERMINAL) —")

      estado_inicial = %{
        usuario_actual: nil,
        pid_partida_actual: nil,
        nodo_servidor: nil
      }

      bucle(estado_inicial)
    end



    defp bucle(estado_consola) do
      opcion =
        menu()
        |> limpiar_texto()

      case opcion do
        "1" ->
          estado_consola |> login() |> bucle()

        "2" ->
          estado_consola |> crear_partida_desde_consola() |> bucle()

        "3" ->
          estado_consola |> listar_partidas_desde_consola() |> bucle()

        "4" ->
          estado_consola |> unirse_desde_consola() |> bucle()

        "5" ->
          estado_consola |> iniciar_partida_desde_consola() |> bucle()

        "8" ->
          estado_consola |> ver_mi_puntaje() |> bucle()

        "9" ->
          estado_consola |> ver_ranking_global() |> bucle()

        "10" ->
          estado_consola |> ver_ranking_tema() |> bucle()

        "0" ->
          estado_consola |> configurar_red() |> bucle()

        "s" ->
          IO.puts("¡Chao!")
          estado_consola

        _otra_opcion ->
          IO.puts("Opción inválida")
          bucle(estado_consola)
      end
    end

    defp menu do
      IO.puts("""
      \n— TRIVIA 🎮  (TERMINAL) —
      1. Registrarse / Ingresar
      2. Crear partida
      3. Listar partidas activas
      4. Unirse a partida por ID
      5. Iniciar partida / Entrar al juego
      8. Ver mi puntaje
      9. Ranking histórico global
      10. Ranking por tema
      0. Configurar red (nodos)
      s. Salir
      """)

      IO.gets("> ")
    end



    defp login(estado_consola) do
      nombre_usuario = pedir("Nombre de usuario: ")
      contrasena = pedir("Contraseña: ")

      case llamar_servidor(estado_consola, :conectar_usuario, [nombre_usuario, contrasena]) do
        {:ok, _tipo_respuesta} ->
          IO.puts("Bienvenido/a #{nombre_usuario}")
          %{estado_consola | usuario_actual: nombre_usuario}

        {:error, :contrasena_invalida} ->
          IO.puts("Contraseña inválida")
          estado_consola

        otra_respuesta ->
          IO.inspect(otra_respuesta, label: "Error al conectar usuario")
          estado_consola
      end
    end



    defp crear_partida_desde_consola(%{usuario_actual: nil} = estado_consola) do
      IO.puts("Primero ingresa.")
      estado_consola
    end

    defp crear_partida_desde_consola(%{usuario_actual: nombre_usuario} = estado_consola) do
      categoria =
        pedir("Categoría (ciencia|historia|deportes|geografia|tecnologia): ")

      cantidad_preguntas =
        pedir_entero("Número de preguntas (5): ", 5)

      segundos_por_pregunta =
        pedir_entero("Segundos por pregunta (15): ", 15)

      maximo_jugadores =
        pedir_entero("Máximo de jugadores (4): ", 4)

      opciones = [
        cantidad_preguntas: cantidad_preguntas,
        segundos_por_pregunta: segundos_por_pregunta,
        max_jugadores: maximo_jugadores
      ]

      case llamar_servidor(estado_consola, :crear_partida, [nombre_usuario, categoria, opciones]) do
        {:ok, identificador_proceso_partida} ->
          resumen_partida =
            llamar_servidor(estado_consola, :obtener_resumen_partida, [identificador_proceso_partida])

          IO.puts("Partida creada. ID: #{resumen_partida.identificador}")
          IO.puts("El creador ya está unido automáticamente a la partida.")

          %{
            estado_consola
            | pid_partida_actual: identificador_proceso_partida
          }

        otra_respuesta ->
          IO.inspect(otra_respuesta, label: "No se pudo crear")
          estado_consola
      end
    end



    defp listar_partidas_desde_consola(estado_consola) do
      IO.puts("\nPartidas activas:")

      lista_resumenes =
        llamar_servidor(estado_consola, :listar_partidas, [])

      if lista_resumenes == [] do
        IO.puts("(ninguna)")
      else
        Enum.each(lista_resumenes, fn resumen ->
          IO.puts(
            "ID: #{resumen.identificador} | Cat: #{resumen.categoria} | " <>
              "Jugadores: #{Enum.join(resumen.jugadores, ", ")} | Iniciada: #{resumen.iniciada}"
          )
        end)
      end

      estado_consola
    end



    defp unirse_desde_consola(%{usuario_actual: nil} = estado_consola) do
      IO.puts("Primero ingresa.")
      estado_consola
    end

    defp unirse_desde_consola(%{usuario_actual: nombre_usuario} = estado_consola) do
      identificador_partida = pedir_entero("ID de la partida: ", nil)

      case llamar_servidor(estado_consola, :unirse_a_partida_por_id, [
             identificador_partida,
             nombre_usuario
           ]) do
        {:ok, :unido, identificador_proceso_partida} ->
          IO.puts("Te uniste")

          %{
            estado_consola
            | pid_partida_actual: identificador_proceso_partida
          }

        {:ok, :ya_estaba, identificador_proceso_partida} ->
          IO.puts("Ya estabas en la partida")

          %{
            estado_consola
            | pid_partida_actual: identificador_proceso_partida
          }

        {:error, :no_encontrada} ->
          IO.puts("No existe")
          estado_consola

        {:error, :llena} ->
          IO.puts("Llena")
          estado_consola

        {:error, :ya_iniciada} ->
          IO.puts("Ya inició")
          estado_consola

        otra_respuesta ->
          IO.inspect(otra_respuesta, label: "Respuesta inesperada al unirse")
          estado_consola
      end
    end


    defp iniciar_partida_desde_consola(%{usuario_actual: nil} = estado_consola) do
      IO.puts("Primero ingresa.")
      estado_consola
    end

    defp iniciar_partida_desde_consola(
           %{usuario_actual: nombre_usuario, pid_partida_actual: pid_partida} = estado_consola
         )
         when is_pid(pid_partida) do
      case llamar_servidor(estado_consola, :obtener_resumen_partida, [pid_partida]) do
        # Ya está iniciada → solo entramos al juego
        %{iniciada: true} ->
          IO.puts("La partida ya está iniciada. Entrando en modo juego…")
          jugar_en_esta_consola(pid_partida, nombre_usuario, estado_consola)
          estado_consola

        # Aún no está iniciada → intentamos iniciarla
        %{iniciada: false} ->
          case llamar_servidor(estado_consola, :iniciar_partida, [pid_partida, nombre_usuario]) do
            {:ok, :iniciada} ->
              IO.puts("¡Empezó! Entrando en modo juego…")
              jugar_en_esta_consola(pid_partida, nombre_usuario, estado_consola)
              estado_consola

            {:error, :solo_creador} ->
              IO.puts(
                "Solo el creador puede iniciar la partida.\n" <>
                  "Cuando la inicie, vuelve a esta opción (5) para ver las preguntas."
              )

              estado_consola

            otra_respuesta ->
              IO.inspect(otra_respuesta, label: "No se pudo iniciar")
              estado_consola
          end

        otra_respuesta ->
          IO.inspect(otra_respuesta, label: "No se pudo obtener el estado de la partida")
          estado_consola
      end
    end

    defp iniciar_partida_desde_consola(estado_consola) do
      IO.puts("No tienes partida seleccionada.")
      estado_consola
    end



    defp jugar_en_esta_consola(pid_partida, nombre_usuario, estado_consola) do
      bucle = fn recurrencia ->
        case llamar_servidor(estado_consola, :obtener_pregunta_actual, [pid_partida]) do
          {:ok, %{texto: texto, opciones: opciones, indice: indice}} ->
            IO.puts("\nPregunta ##{indice + 1}: #{texto}")
            IO.puts("  A) #{opciones["A"]}")
            IO.puts("  B) #{opciones["B"]}")
            IO.puts("  C) #{opciones["C"]}")
            IO.puts("  D) #{opciones["D"]}")

            respuesta =
              IO.gets("Tu respuesta (A/B/C/D). ENTER para omitir: ")
              |> default_a_cadena_vacia()
              |> String.trim()
              |> String.upcase()

            if respuesta in ["A", "B", "C", "D"] do
              case llamar_servidor(estado_consola, :responder_pregunta, [
                     pid_partida,
                     nombre_usuario,
                     respuesta
                   ]) do
                {:ok, puntos} when puntos > 0 ->
                  IO.puts("¡Correcta! +#{puntos}")

                {:ok, puntos} ->
                  IO.puts("Incorrecta (#{puntos})")

                {:error, :ya_respondio} ->
                  IO.puts("Ya respondiste esta pregunta.")

                {:error, :partida_terminada} ->
                  IO.puts("La partida terminó.")

                {:error, motivo} ->
                  IO.puts("Error: #{inspect(motivo)}")
              end
            else
              IO.puts("Sin respuesta. Esperando siguiente pregunta…")
            end

            esperar_siguiente_pregunta(pid_partida, indice, estado_consola)
            recurrencia.(recurrencia)

          {:ok, :esperando} ->
            :timer.sleep(300)
            recurrencia.(recurrencia)

          {:ok, :finalizada} ->
            IO.puts("\n🏁 Partida finalizada")

          {:error, _} ->
            :timer.sleep(300)
            recurrencia.(recurrencia)
        end
      end

      bucle.(bucle)
    end

    defp esperar_siguiente_pregunta(pid_partida, indice_anterior, estado_consola) do
      :timer.sleep(300)

      case llamar_servidor(estado_consola, :obtener_pregunta_actual, [pid_partida]) do
        {:ok, %{indice: indice_nuevo}} when indice_nuevo > indice_anterior ->
          :ok

        {:ok, :finalizada} ->
          :ok

        _ ->
          esperar_siguiente_pregunta(pid_partida, indice_anterior, estado_consola)
      end
    end


    defp ver_mi_puntaje(%{usuario_actual: nil} = estado_consola) do
      IO.puts("Primero ingresa.")
      estado_consola
    end

    defp ver_mi_puntaje(%{usuario_actual: nombre_usuario} = estado_consola) do
      case llamar_servidor(estado_consola, :puntaje_usuario, [nombre_usuario]) do
        {:ok, puntaje} ->
          IO.puts("\n💠 Puntaje de #{nombre_usuario}: #{puntaje} puntos\n")

        {:error, :no_encontrado} ->
          IO.puts("No tienes puntaje registrado.")

        otra_respuesta ->
          IO.inspect(otra_respuesta, label: "Error al consultar puntaje")
      end

      estado_consola
    end

    defp ver_ranking_global(estado_consola) do
      lista = llamar_servidor(estado_consola, :ranking_global, [])

      IO.puts("\n🏆 RANKING GLOBAL")
      IO.puts("----------------------")

      if lista == [] do
        IO.puts("(sin datos aún)")
      else
        Enum.with_index(lista, fn %{nombre: nombre, puntaje_acumulado: puntaje}, indice ->
          IO.puts("#{indice + 1}. #{nombre} — #{puntaje} puntos")
        end)
      end

      IO.puts("----------------------\n")
      estado_consola
    end

    defp ver_ranking_tema(estado_consola) do
      categoria =
        IO.gets("¿Qué categoría deseas ver?: ")
        |> limpiar_texto()

      lista = llamar_servidor(estado_consola, :ranking_por_tema, [categoria])

      IO.puts("\n📚 Ranking por tema: #{categoria}")
      IO.puts("---------------------------")

      if lista == [] do
        IO.puts("(sin partidas registradas para este tema)")
      else
        Enum.with_index(lista, fn %{nombre: nombre, puntaje_total: puntaje}, indice ->
          IO.puts("#{indice + 1}. #{nombre} — #{puntaje} puntos")
        end)
      end

      IO.puts("---------------------------\n")
      estado_consola
    end


    defp configurar_red(estado_consola) do
      nombre_nodo =
        IO.gets("Nombre del nodo local (ej: servidor1, cliente1): ")
        |> limpiar_texto()

      cookie =
        IO.gets("Cookie (ej: mi_cookie): ")
        |> limpiar_texto()
        |> String.to_atom()

      case Node.start(String.to_atom(nombre_nodo), :shortnames) do
        {:ok, _pid_nodo} ->
          Node.set_cookie(cookie)

          IO.puts("""
          Nodo iniciado correctamente.
          Nombre local: #{inspect(Node.self())}
          Cookie: #{cookie}
          """)

          tipo_nodo =
            IO.gets("¿Este nodo será el servidor principal? (s/n): ")
            |> limpiar_texto()
            |> String.downcase()

          nuevo_estado =
            case tipo_nodo do
              "s" ->
                IO.puts("Este nodo actuará como SERVIDOR principal.")
                %{estado_consola | nodo_servidor: Node.self()}

              _otro ->
                nodo_destino =
                  IO.gets(
                    "Nombre del nodo servidor al que deseas conectarte (ej: servidor1@LAPTOP-P2B5LCS0): "
                  )
                  |> limpiar_texto()
                  |> String.to_atom()

                case Node.connect(nodo_destino) do
                  true ->
                    IO.puts("✅ Conectado exitosamente al nodo #{inspect(nodo_destino)}")
                    %{estado_consola | nodo_servidor: nodo_destino}

                  false ->
                    IO.puts("❌ No se pudo conectar al nodo #{inspect(nodo_destino)}")
                    estado_consola
                end
            end

          nuevo_estado

        {:error, razon} ->
          IO.puts("No se pudo iniciar el nodo: #{inspect(razon)}")
          estado_consola
      end
    end


    defp llamar_servidor(estado_consola, nombre_funcion, argumentos) do
      case Map.get(estado_consola, :nodo_servidor) do
        nil ->
          apply(Servidor, nombre_funcion, argumentos)

        nodo_servidor ->
          if nodo_servidor == Node.self() do
            apply(Servidor, nombre_funcion, argumentos)
          else
            :rpc.call(nodo_servidor, Servidor, nombre_funcion, argumentos)
          end
      end
    end

    defp pedir(mensaje) do
      mensaje
      |> IO.gets()
      |> limpiar_texto()
    end

    defp pedir_entero(mensaje, valor_por_defecto) do
      texto_leido =
        mensaje
        |> IO.gets()
        |> limpiar_texto()

      case Integer.parse(texto_leido) do
        {numero, _resto} ->
          numero

        :error ->
          if is_nil(valor_por_defecto) do
            IO.puts("Valor inválido, intenta de nuevo.")
            pedir_entero(mensaje, valor_por_defecto)
          else
            IO.puts("Usando #{valor_por_defecto}")
            valor_por_defecto
          end
      end
    end

    defp limpiar_texto(texto) do
      case texto do
        nil ->
          ""

        texto_cuando_es_binario when is_binary(texto_cuando_es_binario) ->
          String.trim(texto_cuando_es_binario)

        otro_valor ->
          otro_valor
          |> to_string()
          |> String.trim()
      end
    end

    defp default_a_cadena_vacia(valor) do
      case valor do
        nil -> ""
        texto -> texto
      end
    end
  end
end
