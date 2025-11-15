Node.set_cookie(:cookie)
destino = :"nodo2@localhost"
Node.connect(destino)
IO.inspect(Distribuido.ClienteDeTexto.enviar(destino, :mayusculas, "hola mundo"), label: ":mayusculas")
