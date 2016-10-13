#!/bin/bash
set -eu
CONFIGFILE=Config

if [ ! -e "$CONFIGFILE" ]; then
	if [ -n "${1:-}" ]; then
		echo "CONTAINER_NAME=$1" > $CONFIGFILE
		echo "IMAGE_NAME=mariadb-custom" >> $CONFIGFILE
		echo "# EXPOSE_PORT=33061:3306" >> $CONFIGFILE
		echo "Create $CONFIGFILE"
		exit 0
	else
		echo "USAGE: $0 [CONTAINER NAME]"
		exit 1
	fi
fi

. $CONFIGFILE

if [ -z "${CONTAINER_NAME:-}" ]; then
	echo "CONTAINER_NAME not defined"
	exit 2
fi

if [ -z "${IMAGE_NAME:-}" ]; then
	echo "IMAGE_NAME not defined"
	exit 2
fi

# MariaDBの起動を待つ
wait_up_mariadb() {
	perl - $CONTAINER_NAME << '__PERLCODE__'
#!/usr/bin/env perl
use strict;
use warnings;
$|=0;

my $cmariadb=$ARGV[0];
my $flag=0;


my $pid=open(my $io,"docker logs -f $cmariadb 2>&1 |") || die $!;

while(<$io>) {
	print $_;
	if($flag==0) {
		if(/Initializing database/) {
			$flag=1;
			print "--- Initializing database\n";
		} else {
			kill 'TERM',$pid; last;
		}
	}
	if($flag==1) {
		if(/MySQL init process done. Ready for start up/) {
			$flag=2;
			print "--- MySQL init process done. Ready for start up\n";
		}
	}
	if($flag==2) {
		if(/ready for connections/) {
			print "--- ready for connections\n";
			kill 'TERM',$pid; last;
		}
	}
}
__PERLCODE__
}

do_run() {

	if [ -n "$(docker ps | grep $CONTAINER_NAME)" ]; then
		echo "container $CONTAINER_NAME already running."
		exit 1
	fi

	docker build -t $IMAGE_NAME mariadb

	local opt_export_port=
	if [ -n "${EXPOSE_PORT:-}" ]; then
		opt_export_port="-p $EXPOSE_PORT"
	fi
	local docker_run_cmd="docker run -d --name=$CONTAINER_NAME -e MYSQL_RANDOM_ROOT_PASSWORD=yes $opt_export_port $IMAGE_NAME"

	# コンテナの作成
	echo "[RUN] $docker_run_cmd"
	eval $docker_run_cmd
	wait_up_mariadb

	# 自動生成されたrootパスワードを取得
	local mysql_root_passowrd=$(docker logs $CONTAINER_NAME 2>&1 | perl -nle 'if(/^GENERATED ROOT PASSWORD: (.+)$/m) { print $1 }')

   	# /root/.my.cnf に保存する
	docker exec -i $CONTAINER_NAME sh -c 'cat > /root/.my.cnf' << EOT
[client]
user=root
password=$mysql_root_passowrd
EOT
	docker exec -i $CONTAINER_NAME sh << 'EOS'
chmod 600 /root/.my.cnf
EOS

	echo ""
	echo "------------------------------------------------------------------"
	echo " MySQL Client: docker exec -it $CONTAINER_NAME mysql"
	echo " Shutdown:     docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
	echo "------------------------------------------------------------------"
	echo ""

	# MySQL Clientを起動
	exec docker exec -it $CONTAINER_NAME mysql
}

do_mysql() {
	exec docker exec -it $CONTAINER_NAME mysql
}

do_bash() {
	exec docker exec -it $CONTAINER_NAME bash
}

do_destroy() {
	set +e
	docker stop $CONTAINER_NAME
	docker rm   $CONTAINER_NAME
	docker rmi $IMAGE_NAME
}

if [ "${1:-}" == "env" ]; then
	if [ -n "$(docker ps | grep $CONTAINER_NAME)" ]; then
		echo "export MARIADB_HOSTPORT=$(docker inspect $CONTAINER_NAME | jq -r '.[0]["NetworkSettings"]["Ports"]["3306/tcp"][0]["HostPort"]')"
	fi
	echo "export MARIADB_CONTAINER_NAME=$CONTAINER_NAME"
	exit 0
fi

echo "IMAGE NAME:     $IMAGE_NAME"
echo "CONTAINER NAME: $CONTAINER_NAME"

usage() {
	echo "USAGE:"
	echo " $0 run"
	echo " $0 mysql"
	echo " $0 bash"
	echo " $0 destroy"
	echo " $0 env"
	exit 1
}

case "${1:-}" in
	run     ) do_run     ;;
	mysql   ) do_mysql   ;;
	destroy ) do_destroy ;;
	bash    ) do_bash    ;;
	*       ) usage      ;;
esac

