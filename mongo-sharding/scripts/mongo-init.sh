#!/bin/bash

echo "🚀 Инициализация конфигурационного сервера..."
docker-compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
  rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [{ _id: 0, host: "configSrv:27017" }]
  })
EOF

sleep 15

echo "🚀 Инициализация shard1..."
docker-compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
  rs.initiate({
    _id: "shard1",
    members: [{ _id: 0, host: "shard1:27018" }]
  })
EOF

echo "🚀 Инициализация shard2..."
docker-compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
  rs.initiate({
    _id: "shard2",
    members: [{ _id: 1, host: "shard2:27019" }]
  })
EOF

sleep 15

echo "🚀 Добавление шардов в mongos_router..."
docker-compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
  sh.addShard("shard1/shard1:27018");
  sh.addShard("shard2/shard2:27019");
  sh.enableSharding("somedb");
  sh.shardCollection("somedb.helloDoc", { "name": "hashed" });
EOF

sleep 10

echo "🚀 Заполнение базы данными..."
docker-compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
  use somedb;
  for (var i = 0; i < 1000; i++) db.helloDoc.insertOne({ age: i, name: "ly" + i });
  print("Inserted 1000 documents.");
  print("Total documents:", db.helloDoc.countDocuments());
EOF

sleep 10

echo "🎉 MongoDB-кластер готов и заполнен данными!"