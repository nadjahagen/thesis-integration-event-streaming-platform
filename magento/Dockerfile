FROM docker.io/bitnami/magento:2

#fix memory storage issue
COPY composer.json /opt/bitnami/magento/

#insert credentials for extensions
COPY auth.json /.composer/

RUN apt update


