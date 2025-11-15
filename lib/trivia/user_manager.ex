defmodule Trivia.GestorDeUsuarios do
  @moduledoc """
  Gestiona el registro, autenticación y puntajes acumulados de los usuarios.

  Usa un archivo plano `data/users.dat` con el formato:

      nombre_usuario,contrasena,puntaje_acumulado

  Este módulo:
    * Registra e ingresa usuarios.
    * Actualiza puntajes acumulados.
    * Devuelve el ranking global.
    * Permite consultar el puntaje propio.
  """

  @archivo Path.expand("data/users.dat", File.cwd!())
  @external_resource @archivo

  def asegurar_archivo do
    File.mkdir_p!(Path.dirname(@archivo))

    unless File.exists?(@archivo) do
      File.write!(@archivo, "")
    end

    :ok
  end

  defp linea_a_usuario(linea) do
    datos = linea |> String.trim() |> String.split(",")

    case datos do
      [nombre_usuario, contrasena, texto_puntaje] ->
        puntaje_acumulado =
          case Integer.parse(texto_puntaje) do
            {valor, _} -> valor
            :error -> 0
          end

        %{
          nombre: nombre_usuario,
          contrasena: contrasena,
          puntaje_acumulado: puntaje_acumulado
        }

      [nombre_usuario, contrasena] ->
        %{
          nombre: nombre_usuario,
          contrasena: contrasena,
          puntaje_acumulado: 0
        }

      _otra ->
        nil
    end
  end

  defp usuario_a_linea(%{
         nombre: nombre_usuario,
         contrasena: contrasena,
         puntaje_acumulado: puntaje
       }) do
    "#{nombre_usuario},#{contrasena},#{puntaje}\n"
  end

  defp leer_todos_los_usuarios do
    asegurar_archivo()

    @archivo
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&linea_a_usuario/1)
    |> Enum.filter(& &1)  # eliminar nil
  end

  defp escribir_usuarios(lista_usuarios) do
    contenido_archivo =
      lista_usuarios
      |> Enum.map(&usuario_a_linea/1)
      |> IO.iodata_to_binary()

    File.write!(@archivo, contenido_archivo)
  end

  def registrar_o_ingresar(nombre_usuario, contrasena) do
    usuarios = leer_todos_los_usuarios()

    case Enum.find(usuarios, fn usuario -> usuario.nombre == nombre_usuario end) do
      nil ->
        nuevo_usuario = %{
          nombre: nombre_usuario,
          contrasena: contrasena,
          puntaje_acumulado: 0
        }

        escribir_usuarios([nuevo_usuario | usuarios])
        {:registrado, nuevo_usuario}

      %{contrasena: ^contrasena} = usuario_encontrado ->
        {:ingresado, usuario_encontrado}

      _ ->
        {:error, :contrasena_invalida}
    end
  end

  def sumar_puntaje(nombre_usuario, puntos_a_sumar) do
    usuarios = leer_todos_los_usuarios()

    {usuarios_actualizados, encontrado?} =
      Enum.map_reduce(usuarios, false, fn usuario, encontrado_anterior ->
        if usuario.nombre == nombre_usuario do
          usuario_actualizado = %{
            usuario
            | puntaje_acumulado: usuario.puntaje_acumulado + puntos_a_sumar
          }

          {usuario_actualizado, true}
        else
          {usuario, encontrado_anterior}
        end
      end)

    if encontrado? do
      escribir_usuarios(usuarios_actualizados)
      :ok
    else
      {:error, :no_encontrado}
    end
  end

  def ranking_global do
    leer_todos_los_usuarios()
    |> Enum.sort_by(& &1.puntaje_acumulado, :desc)
  end

  def puntaje_propio(nombre_usuario) do
    case Enum.find(leer_todos_los_usuarios(), &(&1.nombre == nombre_usuario)) do
      nil ->
        {:error, :no_encontrado}

      usuario ->
        {:ok, usuario.puntaje_acumulado}
    end
  end
end
