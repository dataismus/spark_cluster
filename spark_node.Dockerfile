FROM alpine:3.9

ENV LANG C.UTF-8

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed !!!!!! SWEET!
RUN { \
		echo '#!/bin/sh'; \
		echo 'set -e'; \
		echo; \
		echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk/jre
ENV PATH $PATH:${JAVA_HOME}/bin:/usr/lib/jvm/java-1.8-openjdk/bin

# Java versioning:
ENV JAVA_VERSION 8u212
ENV JAVA_ALPINE_VERSION 8.212.04-r0
RUN set -x \
	&& apk add --no-cache openjdk8-jre="$JAVA_ALPINE_VERSION" \
	&& [ "$JAVA_HOME" = "$(docker-java-home)" ]


# ----------------------------- Spark setup -------------------------------
# Spark versioning:
ENV APACHE_SPARK_VERSION 2.4.3
ENV DAEMON_RUN=true
ENV HADOOP_VERSION=2.7

RUN apk add --no-cache --virtual=.build-dependencies wget ca-certificates && \
    apk add --no-cache bash curl jq

# COPY spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz /spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz
RUN wget -q https://www-us.apache.org/dist/spark/spark-${APACHE_SPARK_VERSION}/spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
	tar -xzf spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
	mv spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} spark && \
	rm spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz
RUN apk add --no-cache python3

# (py)Spark config
ENV SPARK_HOME /spark
ENV PYTHONPATH $SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.7-src.zip
ENV SPARK_OPTS --driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info
ENV PATH=$SPARK_HOME/bin:$PATH
ENV PYSPARK_PYTHON=python3

######### DRIVER SETUP ######### 
# run it with (as Spark driver):
# docker run --rm -it --name spark-driver --network spark_cluster dataismus/spark_node

# submit an application to the cluster with:
# spark-submit --master spark://spark-master:7077 --class org.apache.spark.examples.SparkPi $SPARK_HOME/examples/jars/spark-examples_2.11-${APACHE_SPARK_VERSION}.jar 100

######### WORKER SETUP ######### 
# ALWAYS chmod +x shell scripts before COPY!
COPY spark_worker/start-worker.sh /
# run it with:
# docker run --rm -it --name spark-worker --hostname spark-worker --network spark_cluster -p 8081:8081 dataismus/spark_node
# start it with:
# CMD spark-class org.apache.spark.deploy.worker.Worker --webui-port $SPARK_WORKER_WEBUI_PORT $SPARK_MASTER
# or, equivalently, by default:
# CMD spark-class org.apache.spark.deploy.worker.Worker --webui-port 8081 spark://spark-master:7077 --webui-port 8081


######### MASTER SETUP ######### 
# ALWAYS chmod +x shell scripts before COPY!
COPY spark_master/start-master.sh /
# run it with:
# docker run --rm -it --name spark-master --hostname spark-master --network spark_cluster -p 7077:7077 -p 8080:8080 dataismus/spark_node

# start it with:
# CMD spark-class org.apache.spark.deploy.master.Master --ip $SPARK_LOCAL_IP --port $SPARK_MASTER_PORT --webui-port $SPARK_MASTER_WEBUI_PORT
# or, equivalently, by default:
# CMD spark-class org.apache.spark.deploy.master.Master --ip `hostname` --port 7077 --webui-port 8080


EXPOSE 8080 8081 7077 6066
CMD /bin/sh 
