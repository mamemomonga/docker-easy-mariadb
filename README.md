# 即席MariaDB 

DockerのMariaDBをすぐに使うためのスクリプトです。

# 必要な環境

* Docker
* jq
* bashなど

# 機能

* 自動生成のMySQL rootパスワードを /root/.my.cnf に保存し、コンテナのUNIX rootユーザはパスワードなしでMySQL rootユーザでログインできます。
* mariadb/mariadb.cnf を調整することで、サーバ起動パラメータを調整できます。

[mariadb/Dockerfile](mariadb/Dockerfile) で https://hub.docker.com/_/mariadb/ にある mariadb:10.1 の mariadb.cnf を書き換えています。

# 使い方

Config生成

	./docker-mariadb [コンテナ名]

を実行すると、Configが作成されます。
EXPOSE_PORT の部分をコメントアウトすることで、MySQL TCP接続を利用できるようになります。
また、コンテナ名やイメージ名の変更もできます。
Configを設定すると、以下のようなコマンドが使えるようになります。

	./docker-mariadb.sh run      イメージビルドとコンテナ起動
	./docker-mariadb.sh destroy  コンテナの停止と削除、およびイメージの削除
	./docker-mariadb.sh mysql    MySQL Client実行(MySQL rootユーザ)
	./docker-mariadb.sh bash     Bash実行(UNIX rootユーザ)
	./docker-mariadb.sh env      設定の一部を環境変数用に出力する

run

	./docker-mariadb run

を実行すると、
* mariadbディレクトリの下にあるDockerfileをbuild
* buildしたものをrunしMariaDB Serverの起動
* rootパスワードの設定
* MariaDB Clientの起動
が行われます。

# 使用例

	$ docker pull mariadb
	$ ./docker-mariadb.sh [コンテナ名]
	$ vim Config
	$ ./docker-mariadb.sh run

Config ファイルを作成する

	./docker-mariadb.sh cmariadb

EXPOSE_PORT をコメントアウトすることで docker run -p オプションを設定できる

	vim Config

docker run の後 MariaDB clientを起動

	./docker-mariadb.sh run
	MariaDB [(none)]> create database thedb;

一部設定内容を環境変数に設定する

	./docker-mariadb.sh env
	eval $(./docker-mariadb.sh env)

データのインポート

	docker exec -i $MARIADB_CONTAINER_NAME mysql thedb < thedb.sql

TCP接続のためのアカウントを設定する

	echo "GRANT ALL PRIVILEGES ON thedb.* TO admin@'%' IDENTIFIED BY 'password'" | docker exec -i $MARIADB_CONTAINER_NAME mysql

接続の確認

	mysql -h 127.0.0.1 -P $MARIADB_HOSTPORT -u admin -p thedb

# mariadb.cnf の設定
デフォルトの設定がutf8になるように調整してあります。

	MariaDB [(none)]> show variables like 'char%';
	+--------------------------+----------------------------+
	| Variable_name            | Value                      |
	+--------------------------+----------------------------+
	| character_set_client     | utf8                       |
	| character_set_connection | utf8                       |
	| character_set_database   | utf8                       |
	| character_set_filesystem | binary                     |
	| character_set_results    | utf8                       |
	| character_set_server     | utf8                       |
	| character_set_system     | utf8                       |
	| character_sets_dir       | /usr/share/mysql/charsets/ |
	+--------------------------+----------------------------+


