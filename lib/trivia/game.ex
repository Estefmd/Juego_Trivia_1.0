defmodule Trivia.Partida do
  @moduledoc """
  Representa una partida de trivia.

  Responsabilidades principales:
    * Gestionar jugadores que se unen a la partida.
    * Controlar el inicio de la partida.
    * Administrar preguntas, respuestas y puntajes.
    * Manejar el temporizador por pregunta.
    * Guardar resultados y actualizar puntajes globales de usuarios.
  """

  use GenServer

  alias Trivia.{BancoDePreguntas, GestorDeUsuarios}

  defstruct [
  :identificador,
  :categoria,
  :creador,
  :max_jugadores,
  :segundos_por_pregunta,
  :preguntas,
  :indice_actual,
  :iniciada?,
  :temporizador_pid,
  jugadores: %{},
  respondieron: %{}
]


  def start_link(opciones) do
    GenServer.start_link(__MODULE__, opciones)
  end

  def obtener_resumen(identificador_proceso_partida) do
    GenServer.call(identificador_proceso_partida, :obtener_resumen)
  end

  def unirse(identificador_proceso_partida, nombre_jugador) do
    GenServer.call(identificador_proceso_partida, {:unirse, nombre_jugador})
  end

  def iniciar(identificador_proceso_partida, nombre_solicitante) do
    GenServer.call(identificador_proceso_partida, {:iniciar, nombre_solicitante})
  end

  def responder(identificador_proceso_partida, nombre_jugador, opcion_elegida) do
    opcion_normalizada = String.upcase(opcion_elegida)

    try do
      GenServer.call(
        identificador_proceso_partida,
        {:responder, nombre_jugador, opcion_normalizada}
      )
    catch
      :exit, {:noproc, _motivo} ->
        {:error, :partida_terminada}

      :exit, _otro ->
        {:error, :partida_terminada}
    end
  end

  def obtener_pregunta_actual(identificador_proceso_partida) do
    try do
      GenServer.call(identificador_proceso_partida, :obtener_pregunta_actual)
    catch
      :exit, {:noproc, _motivo} ->
        {:ok, :finalizada}

      :exit, _otro ->
        {:ok, :finalizada}
    end
  end


  @impl true
  def init(opciones) do
    categoria = Keyword.fetch!(opciones, :categoria)

    preguntas =
      BancoDePreguntas.aleatorias_por_categoria(
        categoria,
        Keyword.get(opciones, :cantidad_preguntas, 5)
      )

    estado_inicial = %__MODULE__{
      identificador: Keyword.fetch!(opciones, :identificador),
      categoria: categoria,
      creador: Keyword.fetch!(opciones, :creador),
      max_jugadores: Keyword.get(opciones, :max_jugadores, 4),
      segundos_por_pregunta: Keyword.get(opciones, :segundos_por_pregunta, 15),
      preguntas: preguntas,
      indice_actual: -1,
      iniciada?: false
    }

    {:ok, estado_inicial}
  end

  @impl true
  def handle_call(:obtener_resumen, _from_mensaje, estado_actual) do
    resumen = %{
      identificador: estado_actual.identificador,
      categoria: estado_actual.categoria,
      iniciada: estado_actual.iniciada?,
      indice_actual: estado_actual.indice_actual,
      jugadores: Map.keys(estado_actual.jugadores),
      max_jugadores: estado_actual.max_jugadores
    }

    {:reply, resumen, estado_actual}
  end

  @impl true
  def handle_call(:obtener_pregunta_actual, _from_mensaje, estado_actual) do
    cond do
      estado_actual.iniciada? == false ->
        {:reply, {:error, :no_iniciada}, estado_actual}

      estado_actual.indice_actual < 0 ->
        {:reply, {:ok, :esperando}, estado_actual}

      estado_actual.indice_actual >= length(estado_actual.preguntas) ->
        {:reply, {:ok, :finalizada}, estado_actual}

      true ->
        pregunta_actual = Enum.at(estado_actual.preguntas, estado_actual.indice_actual)

        informacion_pregunta = %{
          texto: pregunta_actual.texto,
          opciones: pregunta_actual.opciones,
          indice: estado_actual.indice_actual
        }

        {:reply, {:ok, informacion_pregunta}, estado_actual}
    end
  end

  @impl true
  def handle_call({:unirse, nombre_jugador}, _from_mensaje, estado_actual) do
    cond do
      estado_actual.iniciada? ->
        {:reply, {:error, :ya_iniciada}, estado_actual}

      map_size(estado_actual.jugadores) >= estado_actual.max_jugadores ->
        {:reply, {:error, :llena}, estado_actual}

      Map.has_key?(estado_actual.jugadores, nombre_jugador) ->
        {:reply, {:ok, :ya_estaba}, estado_actual}

      true ->
        nuevo_estado =
          put_in(estado_actual.jugadores[nombre_jugador], %{
            puntaje: 0
          })

        {:reply, {:ok, :unido}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:iniciar, nombre_solicitante}, _from_mensaje, estado_actual) do
    cond do
      nombre_solicitante != estado_actual.creador ->
        {:reply, {:error, :solo_creador}, estado_actual}

      estado_actual.iniciada? ->
        {:reply, {:error, :ya_iniciada}, estado_actual}

      true ->
        estado_iniciado = %{estado_actual | iniciada?: true, indice_actual: -1}
        nuevo_estado = programar_siguiente_pregunta(estado_iniciado)
        {:reply, {:ok, :iniciada}, nuevo_estado}
    end
  end

@impl true
def handle_call({:responder, nombre_jugador, opcion_elegida}, _from_mensaje, estado_actual) do
  cond do
    estado_actual.iniciada? == false ->
      {:reply, {:error, :no_iniciada}, estado_actual}

    Map.has_key?(estado_actual.jugadores, nombre_jugador) == false ->
      {:reply, {:error, :no_en_partida}, estado_actual}

    Map.get(estado_actual.respondieron, nombre_jugador, false) ->
      {:reply, {:error, :ya_respondio}, estado_actual}

    true ->
      pregunta_actual = Enum.at(estado_actual.preguntas, estado_actual.indice_actual)

      respuesta_correcta = normalizar_opcion(pregunta_actual.correcta)
      opcion_normalizada = normalizar_opcion(opcion_elegida)

      puntos_obtenidos =
        if opcion_normalizada == respuesta_correcta do
          10
        else
          -5
        end

      jugadores_actualizados =
        Map.update!(estado_actual.jugadores, nombre_jugador, fn informacion_jugador ->
          %{
            informacion_jugador
            | puntaje: informacion_jugador.puntaje + puntos_obtenidos
          }
        end)

      respondieron_actualizado =
        Map.put(estado_actual.respondieron, nombre_jugador, true)

      estado_actualizado = %{
        estado_actual
        | jugadores: jugadores_actualizados,
          respondieron: respondieron_actualizado
      }


      todos_respondieron? =
        map_size(estado_actualizado.respondieron) >=
          map_size(estado_actualizado.jugadores)

      estado_final =
        if todos_respondieron? do

          programar_siguiente_pregunta(estado_actualizado)
        else

          estado_actualizado
        end

      {:reply, {:ok, puntos_obtenidos}, estado_final}
  end
end


  @impl true
  def handle_info(:fin_de_pregunta, estado_actual) do
    estado_sin_respuestas = %{estado_actual | respondieron: %{}}

    if estado_sin_respuestas.indice_actual + 1 >= length(estado_sin_respuestas.preguntas) do
      finalizar(estado_sin_respuestas)
    else
      nuevo_estado = programar_siguiente_pregunta(estado_sin_respuestas)
      {:noreply, nuevo_estado}
    end
  end


defp programar_siguiente_pregunta(estado_actual) do

  if is_pid(estado_actual.temporizador_pid) do
    send(estado_actual.temporizador_pid, :cancelar)
  end

  nuevo_indice = estado_actual.indice_actual + 1

  nuevo_temporizador_pid =
    iniciar_temporizador(
      self(),
      estado_actual.segundos_por_pregunta * 1000
    )

  %{
    estado_actual
    | indice_actual: nuevo_indice,
      temporizador_pid: nuevo_temporizador_pid
  }
end


defp iniciar_temporizador(identificador_proceso_partida, milisegundos) do
  spawn(fn ->
    receive do
      :cancelar ->
        :ok
    after
      milisegundos ->
        send(identificador_proceso_partida, :fin_de_pregunta)
    end
  end)
end


  defp normalizar_opcion(valor) do
    valor
    |> String.trim()
    |> String.upcase()
    |> String.graphemes()
    |> List.first()
  end

  defp finalizar(estado_actual) do
    {nombre_ganador, _puntaje_maximo} =
      estado_actual.jugadores
      |> Enum.max_by(
        fn {_nombre_jugador, informacion_jugador} -> informacion_jugador.puntaje end,
        fn -> {"sin_jugadores", %{puntaje: 0}} end
      )

    ruta_archivo = Path.expand("data/results.log", File.cwd!())
    File.mkdir_p!(Path.dirname(ruta_archivo))

    encabezado = [
      "Ganador: #{nombre_ganador}",
      "Categoría: #{estado_actual.categoria}",
      "Puntajes:"
    ]

    lineas_puntajes =
      Enum.map(estado_actual.jugadores, fn {nombre_jugador, informacion_jugador} ->
        "- #{nombre_jugador}: #{informacion_jugador.puntaje}"
      end)

    contenido_log =
      (encabezado ++ lineas_puntajes)
      |> Enum.join("\n")

    File.write!(ruta_archivo, contenido_log <> "\n---\n", [:append])

    estado_actual.jugadores
    |> Task.async_stream(
      fn {nombre_jugador, informacion_jugador} ->
        GestorDeUsuarios.sumar_puntaje(nombre_jugador, informacion_jugador.puntaje)
      end,
      timeout: 5_000
    )
    |> Enum.to_list()

    {:stop, :normal, estado_actual}
  end
end
