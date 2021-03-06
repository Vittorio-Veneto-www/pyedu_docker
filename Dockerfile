# syntax=docker/dockerfile:1
# FROM mattrayner/lamp:latest-1804
FROM ubuntu:18.04
RUN useradd -ms /bin/bash -d /home/lab409 lab409
USER root
WORKDIR /home/lab409

# 去掉一些无用报错信息
RUN printf "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d
RUN chmod +x /usr/sbin/policy-rc.d

# 安装MySQL时跳过创建root密码步骤，防止卡死
ARG DEBIAN_FRONTEND noninteractive
RUN { \
        echo debconf debconf/frontend select Noninteractive; \
    } | debconf-set-selections

#设置Python IO编码
ENV PYTHONIOENCODING UTF-8

# 安装命令

# 换清华源源加快apt速度

RUN mv /etc/apt/sources.list /etc/apt/sources_bak.list &&\
  echo 'deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse\n\
  deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse\n\
  deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse\n\
  deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse' > /etc/apt/sources.list &&\
  apt-get clean &&\
  apt-get update

RUN apt-get install -y ca-certificates gnupg
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8C718D3B5072E1F5

RUN echo 'deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse\n\
  deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse\n\
  deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse\n\
  deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse' > /etc/apt/sources.list &&\
  echo 'deb https://mirrors.tuna.tsinghua.edu.cn/mysql/apt/ubuntu bionic mysql-5.6 mysql-5.7 mysql-8.0 mysql-tools' > /etc/apt/sources.list.d/mysql-community.list &&\
  apt-get clean &&\
  apt-get update

RUN apt-get install -y apache2 libapache2-mod-wsgi-py3
RUN apt-get install -y python3-pip git
RUN apt-get install -y mysql-server mysql-client

# apt安装的pip版本太低，不支持config方法
# RUN pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
RUN mkdir ~/.pip &&\
  echo '[global]\n\
  index-url = https://pypi.tuna.tsinghua.edu.cn/simple' > ~/.pip/pip.conf &&\
  pip3 install django django-filter django-cron numpy pymysql yapf

# 从github上拉取的代码竞技场文件，加快build速度
COPY arena ./arena
COPY pyedu ./pyedu

# github速度慢，使用本地缓存的结果
# RUN git clone -b num_chooser_alias --recurse-submodules https://github.com/YukkuriC/django_ai_arena.git arena
# RUN git clone -b avg_score http://162.105.17.143:1280/YukkuriC/pyedu.collection.git pyedu

ENV SECRET_KEY xianbei
ENV MYSQL_DB test
ENV MYSQL_USER django
ENV MYSQL_PASSWD test
ENV DJANGO_SUPERUSER_USERNAME test
ENV DJANGO_SUPERUSER_EMAIL a@b.cd
ENV DJANGO_SUPERUSER_PASSWORD 114514

# 写入setup.json和override.json
RUN echo "{\"SECRET_KEY\" : \"$SECRET_KEY\"}" > /home/lab409/arena/.env &&\
  echo "{\"SECRET_KEY\" : \"$SECRET_KEY\",\"DEBUG\" : 1}" > /home/lab409/arena/override.json &&\
  echo "{\"SECRET_KEY\" : \"$SECRET_KEY\",\"MYSQL_DB\" : \"$MYSQL_DB\",\"MYSQL_USER\" : \"$MYSQL_USER\",\"MYSQL_PASSWD\" : \"$MYSQL_PASSWD\",\"MYSQL_HOST\" : \"127.0.0.1\",\"MYSQL_PORT\" : \"3306\"}" > /home/lab409/pyedu/pyedu/setup.json &&\
  echo "{\"SECRET_KEY\" : \"$SECRET_KEY\",\"DEBUG\" : 1}" > /home/lab409/pyedu/pyedu/override.json

# 需要将apache使用www-data用户写入的文件
# 例如数据库文件和用户上传的内容
# 写入到一个与git仓库隔离的目录中并控制权限
RUN chgrp -R www-data arena &&\
  chgrp -R www-data pyedu&&\
  adduser lab409 www-data

# For WSL
RUN echo '\nAcceptFilter http none' >> /etc/apache2/apache2.conf &&\
echo '\nListen 8000\n\
Listen 8001' >> /etc/apache2/ports.conf &&\
echo '<VirtualHost *:8000>\n\
    ServerAdmin yukkuri@pku.edu.cn\n\
\n\
    Alias /assets /home/lab409/arena/assets\n\
    Alias /STORAGE /home/lab409/arena/_STORAGE\n\
\n\
    <Directory /home/lab409/arena/assets>\n\
        Require all granted\n\
    </Directory>\n\
\n\
    <Directory /home/lab409/arena/_STORAGE>\n\
        Require all granted\n\
    </Directory>\n\
\n\
    WSGIScriptAlias / /home/lab409/arena/main/wsgi.py\n\
\n\
    <Directory /home/lab409/arena/main>\n\
        <Files wsgi.py>\n\
            Require all granted\n\
        </Files>\n\
    </Directory>\n\
\n\
    <Directory /home/lab409/arena>\n\
        <Files db.sqlite3>\n\
            Require all granted\n\
        </Files>\n\
    </Directory>\n\
</VirtualHost>' > /etc/apache2/sites-available/arena.conf &&\
echo '<VirtualHost *:8001>\n\
    ServerAdmin yukkuri@pku.edu.cn\n\
\n\
    Alias /static /home/lab409/pyedu/pyedu/static\n\
    Alias /STORAGE /home/lab409/pyedu/pyedu/_STORAGE\n\
\n\
    <Directory /home/lab409/pyedu/pyedu/static>\n\
        Require all granted\n\
    </Directory>\n\
\n\
    <Directory /home/lab409/pyedu/pyedu/_STORAGE>\n\
        Require all granted\n\
    </Directory>\n\
\n\
    WSGIScriptAlias / /home/lab409/pyedu/pyedu/main/wsgi.py\n\
    <Directory /home/lab409/pyedu/pyedu>\n\
        <Files database.db>\n\
            Require all granted\n\
        </Files>\n\
    </Directory>\n\
    <Directory /home/lab409/pyedu/pyedu/main>\n\
        <Files wsgi.py>\n\
            Require all granted\n\
        </Files>\n\
    </Directory>\n\
</VirtualHost>' > /etc/apache2/sites-available/pyedu.conf

RUN a2ensite arena &&\
  a2ensite pyedu

# pyedu初始化部分 使用MySQL 故包括了MySQL初始化
# 对错误代码的临时修正
# COPY settings.py /home/lab409/pyedu/pyedu/main/
RUN sed -i "s/if True:/if False:/ ; s/1, 3, 13/1, 4, 0/" /home/lab409/pyedu/pyedu/main/settings.py

RUN sed -i "s/.*datadir.*/datadir\t\t= \/var\/lib\/mysql\/data/" /etc/mysql/mysql.conf.d/mysqld.cnf &&\
  echo "user\t\t= www-data" >> /etc/mysql/mysql.conf.d/mysqld.cnf &&\
  mkdir /var/lib/mysql/data &&\
  chown -R www-data /var/lib/mysql/data &&\
  chown -R www-data /var/lib/mysql &&\
  chown -R www-data /var/run/mysqld &&\
  chown -R www-data /var/log/mysql &&\
  mysqld --initialize-insecure &&\
  echo "create database $MYSQL_DB;\n\
    create user '$MYSQL_USER'@'localhost' identified by '$MYSQL_PASSWD';\n\
    grant usage on *.* to '$MYSQL_USER'@'localhost';\n\
    grant all privileges on $MYSQL_DB.* to '$MYSQL_USER'@'localhost';"\ > createuser.sql &&\
  echo "mysqld &" > /tmp/config &&\
  echo "mysqladmin --silent --wait=100 ping || exit 1" >> /tmp/config &&\
  echo "mysql -uroot < createuser.sql" >> /tmp/config &&\
  echo "python3 /home/lab409/pyedu/tools/migrate.py" >> /tmp/config &&\
  echo "python3 /home/lab409/pyedu/pyedu/manage.py collectstatic --no-input" >> /tmp/config &&\
  echo "if [ \"$DJANGO_SUPERUSER_USERNAME\" ]\n\
    then\n\
    python3 /home/lab409/pyedu/pyedu/manage.py createsuperuser --no-input --username $DJANGO_SUPERUSER_USERNAME --email $DJANGO_SUPERUSER_EMAIL\n\
    fi" >> /tmp/config &&\
  bash /tmp/config &&\
  rm -f /tmp/config createuser.sql &&\
  mysqladmin shutdown

# arena初始化部分 使用sqlite
RUN echo "python3 /home/lab409/arena/update_sql.py" > /tmp/config &&\
  echo "chown -R www-data /home/lab409/arena/db.sqlite3" >> /tmp/config &&\
  echo "chown -R www-data /home/lab409/arena" >> /tmp/config &&\
  echo "python3 /home/lab409/arena/manage.py collectstatic --no-input" >> /tmp/config &&\
  echo "if [ \"$DJANGO_SUPERUSER_USERNAME\" ]\n\
    then\n\
    python3 /home/lab409/arena/manage.py createsuperuser --no-input --username $DJANGO_SUPERUSER_USERNAME --email $DJANGO_SUPERUSER_EMAIL\n\
    fi" >> /tmp/config &&\
  bash /tmp/config

EXPOSE 8000 8001

# CMD apachectl start | mysqld
CMD apachectl start | tail -f /dev/null