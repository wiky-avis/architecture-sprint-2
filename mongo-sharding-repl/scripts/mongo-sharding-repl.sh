#!/bin/bash

###
# Инициализируем бд
###

echo "Старт всех контейнеров"
docker compose up -d

echo "Подключение к серверу конфигурации и инициализация"
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
)
EOF

echo "Инициализация шардов"
docker compose exec -T shard1-a mongosh --port 27122 --quiet <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1-a:27122" },
        { _id : 1, host : "shard1-b:27123" },
        { _id : 2, host : "shard1-c:27124" }
      ]
    }
)
EOF

sleep 10

docker compose exec -T shard2-a mongosh --port 27125 --quiet <<EOF
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2-a:27125" },
        { _id : 1, host : "shard2-b:27126" },
        { _id : 2, host : "shard2-c:27127" }
      ]
    }
)
EOF

sleep 10

docker compose exec -T shard3-a mongosh --port 27128 --quiet <<EOF
rs.initiate(
    {
      _id : "shard3",
      members: [
        { _id : 0, host : "shard3-a:27128" },
        { _id : 1, host : "shard3-b:27129" },
        { _id : 2, host : "shard3-c:27130" }
      ]
    }
)
EOF

sleep 10

echo "Инцициализация роутеров"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard( "shard1/shard1-a:27122,shard1-b:27123,shard1-c:27124" )
sh.addShard( "shard2/shard2-a:27125,shard2-b:27126,shard2-c:27127" )
sh.addShard( "shard3/shard3-a:27128,shard3-b:27129,shard3-c:27130" )
sleep 5
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
EOF

echo "Заполняем mongodb данными"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
db.helloDoc.countDocuments()
EOF

docker-compose exec -T mongos_router mongosh --port 27020  --quiet <<EOF
db.adminCommand({ getShardMap: 1 })
EOF
