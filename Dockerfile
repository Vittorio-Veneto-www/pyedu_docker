# syntax=docker/dockerfile:1
FROM mattrayner/lamp:latest-1804
RUN useradd -ms /bin/bash -d /home/lab409 lab409
USER root
WORKDIR /home/lab409

# 去掉一些无用报错信息
RUN printf "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d
RUN chmod +x /usr/sbin/policy-rc.d

# 从github上拉取的代码竞技场文件，加快build速度
# COPY arena ./arena

# 安装命令

# 换清华源源加快apt速度

RUN mv /etc/apt/sources.list /etc/apt/sources_bak.list &&\
  echo 'deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse\n\
  deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse\n\
  deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse\n\
  deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse' > /etc/apt/sources.list &&\
  apt-get clean &&\
  apt-get update

# github速度慢，使用本地缓存的结果
# RUN git clone -b num_chooser_alias --recurse-submodules https://github.com/YukkuriC/django_ai_arena.git arena
mkdir arena
RUN git clone -b avg_score http://162.105.17.143:1280/YukkuriC/pyedu.collection.git pyedu

# 写入setup.json和override.json
RUN echo "{}" > /home/lab409/pyedu/pyedu/setup.json &&\
  echo "{\"SECRET_KEY\" : \"xianbei\"}" > /home/lab409/arena/override.json &&\
  echo "{\"SECRET_KEY\" : \"xianbei\"}" > /home/lab409/pyedu/pyedu/override.json

# 需要将apache使用www-data用户写入的文件
# 例如数据库文件和用户上传的内容
# 写入到一个与git仓库隔离的目录中并控制权限
RUN chgrp -R www-data arena &&\
  chgrp -R www-data pyedu

RUN apt-get install -y libapache2-mod-wsgi-py3 python3-pip

# apt安装的pip版本太低，不支持config方法
# RUN pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
RUN mkdir ~/.pip &&\
  echo '[global]\n\
  index-url = https://pypi.tuna.tsinghua.edu.cn/simple' > ~/.pip/pip.conf &&\
  pip3 install django django-filter django-cron numpy pymysql yapf

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

EXPOSE 8000 8001

# 代码竞技场使用的SECRET_KEY
ENV SECRET_KEY 114514
CMD apachectl start | tail -f /dev/null
