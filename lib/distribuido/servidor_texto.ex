defmodule Distribuido.ServidorDeTexto do
  @moduledoc """
  Servidor de texto que aplica distintas transformaciones o análisis sobre cadenas:

    * Convertir a mayúsculas
    * Convertir a minúsculas
    * Verificar si una cadena es palíndroma
    * Contar vocales (incluye tildes)

  El proceso se registra con el nombre global `:servidor_texto`.
  """

  def iniciar do
    Process.register(self(), :servidor_texto)
    bucle_servidor()
  end


  defp bucle_servidor do
    receive do
      {:mayusculas, texto, remitente} ->
        respuesta = String.upcase(texto)
        send(remitente, {:respuesta, respuesta})
        bucle_servidor()

      {:minusculas, texto, remitente} ->
        respuesta = String.downcase(texto)
        send(remitente, {:respuesta, respuesta})
        bucle_servidor()

      {:palindroma, texto, remitente} ->
        es_palindroma = palindroma?(texto)
        send(remitente, {:respuesta, es_palindroma})
        bucle_servidor()

      {:contar_vocales, texto, remitente} ->
        cantidad_vocales = contar_vocales(texto)
        send(remitente, {:respuesta, cantidad_vocales})
        bucle_servidor()

      :fin ->
        :ok

      mensaje_desconocido ->
        IO.puts("Mensaje no reconocido: #{inspect(mensaje_desconocido)}")
        bucle_servidor()
    end
  end


  defp palindroma?(texto) do
    texto_limpio =
      texto
      |> String.downcase()
      |> String.replace(~r/[^a-záéíóúñ0-9]/u, "")

    texto_limpio == String.reverse(texto_limpio)
  end

  defp contar_vocales(texto) do
    texto
    |> String.downcase()
    |> String.graphemes()
    |> Enum.count(fn caracter ->
      caracter in ["a", "e", "i", "o", "u", "á", "é", "í", "ó", "ú"]
    end)
  end
end
