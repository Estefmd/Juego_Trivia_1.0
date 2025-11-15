defmodule Distribuido.ServidorDeNumeros do
  @moduledoc """
  Servidor simple que recibe una lista de números y responde la suma y el promedio.
  Este proceso se registra con el nombre `:servidor_numeros` para permitir acceso global.
  """

  def iniciar do
    Process.register(self(), :servidor_numeros)
    bucle_servidor()
  end

  defp bucle_servidor do
    receive do
      {:lista, numeros, remitente} when is_list(numeros) ->
        suma_total = Enum.sum(numeros)

        promedio =
          case length(numeros) do
            0 -> 0
            cantidad -> suma_total / cantidad
          end

        respuesta = %{suma: suma_total, promedio: promedio}

        send(remitente, {:respuesta, respuesta})
        bucle_servidor()

      :fin ->
        :ok

      mensaje_desconocido ->
        IO.puts("Mensaje no reconocido: #{inspect(mensaje_desconocido)}")
        bucle_servidor()
    end
  end
end
