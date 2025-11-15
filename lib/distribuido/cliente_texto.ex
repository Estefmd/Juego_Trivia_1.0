defmodule Distribuido.ClienteDeTexto do
  def enviar(nodo_destino, operacion, texto) do
    destino = {:servidor_texto, nodo_destino}
    send(destino, {operacion, texto, self()})
    receive do {:respuesta, valor} -> {:ok, valor} after 3_000 -> {:error, :timeout} end
  end
end
