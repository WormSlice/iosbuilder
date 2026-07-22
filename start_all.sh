#!/bin/bash

# Iniciar Meilisearch en segundo plano si no está corriendo
if ! lsof -i :7701 > /dev/null; then
  echo "Iniciando Meilisearch en el puerto 7701..."
  ./meilisearch --master-key master_key --http-addr "0.0.0.0:7701" > meilisearch.log 2>&1 &
  echo "Meilisearch iniciado en http://localhost:7701 (binding 0.0.0.0)"
else
  echo "Meilisearch ya está en ejecución en el puerto 7701."
fi

# Iniciar Admin Panel
echo "Iniciando CONNECT Admin Panel..."
cd admin && npm run dev
