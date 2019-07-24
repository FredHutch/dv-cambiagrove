FROM ubuntu:latest
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update
RUN apt-get -y install unzip awscli python3-pip sudo
RUN python3 -m pip install boto3 pandas
ADD fetch_and_run.sh /usr/local/bin/fetch_and_run.sh
RUN sudo chmod +x /usr/local/bin/fetch_and_run.sh
WORKDIR /tmp
USER root
ENTRYPOINT ["/usr/local/bin/fetch_and_run.sh"]