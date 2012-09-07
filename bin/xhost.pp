define db($port = 80, $user = root, $password, $host = "127.0.0.1", $database = $name) produces sql() {
  notify { "db $name, password $password": }
}

define web($dbport, $dbuser, $dbpassword, $dbhost, $database) consumes sql(
  $port      = dbport,
  $user      = dbuser,
  $password  = dbpassword,
  $host      = dbhost,
  $database  = database
) {
  notify { "web $name, password $dbpassword user $dbuser": }
}

node direct {
  db { one: password => "passw0rd" }
  web { one: require => Db[one] }
}

node indirect {
  db { one: password => "passw0rd", produce => Sql[one] }
  web { one: consume => Sql[one] }
}

node db1 {
  db { one: password => "passw0rd", produce => Sql[one] }
}

node web1 {
  web { one:
    consume => Sql[one]
  }
}
