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

echo "Инициализация Replicaset..."
docker-compose exec -T mongodb11 mongosh --port 27011 --quiet <<EOF
  rs.initiate({
    _id: "rs0", 
	members: [{_id: 0, host: "mongodb11:27011"},
     {_id: 1, host: "mongodb12:27012"},
     {_id: 2, host: "mongodb13:27013"}
  ]}) 
EOF

docker-compose exec -T mongodb21 mongosh --port 27021 --quiet <<EOF
  rs.initiate({
    _id: "rs1", members: [
    {_id: 0, host: "mongodb21:27021"},
    {_id: 1, host: "mongodb22:27022"},
    {_id: 2, host: "mongodb23:27023"}
  ]}) 
EOF

sleep 15

echo "🚀 Добавление шардов в mongos_router..."
docker-compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
  sh.addShard("rs0/mongodb11:27011,mongodb12:27012,mongodb13:27013");
  sh.addShard("rs1/mongodb21:27021,mongodb22:27022,mongodb23:27023");
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