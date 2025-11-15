defmodule Distribuido.ClienteDeNumeros do
  def enviar_lista(nodo_destino, lista) when is_list(lista) do
    destino = {:servidor_numeros, nodo_destino}
    send(destino, {:lista, lista, self()})
    receive do {:respuesta, mapa} -> {:ok, mapa} after 3_000 -> {:error, :timeout} end
  end
end
