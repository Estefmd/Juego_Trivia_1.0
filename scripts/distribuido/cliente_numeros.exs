Node.set_cookie(:cookie)
destino = :"nodo2@localhost"
Node.connect(destino)
IO.inspect(Distribuido.ClienteDeNumeros.enviar_lista(destino, [1,2,3,4,5]), label: "suma/promedio")
