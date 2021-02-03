#/bin/bash

DOCKER_HOST=$(terraform output docker_host)
DOCKER_HOST=$(sed -e 's/^"//' -e 's/"$//' <<< $DOCKER_HOST)

DOCKER_USER=$(terraform output docker_user)
DOCKER_USER=$(sed -e 's/^"//' -e 's/"$//' <<< $DOCKER_USER)

DOCKER_PASSWORD=$(terraform output docker_password)
DOCKER_PASSWORD=$(sed -e 's/^"//' -e 's/"$//' <<< $DOCKER_PASSWORD)

DOCKER_IMAGE_SCOPE=$(terraform output docker_image_scope)
DOCKER_IMAGE_SCOPE=$(sed -e 's/^"//' -e 's/"$//' <<< $DOCKER_IMAGE_SCOPE)
cd ..

# docker login https://${DOCKER_HOST}/v2/ -u $DOCKER_USER -p $DOCKER_PASSWORD 
docker login $DOCKER_HOST -u $DOCKER_USER -p $DOCKER_PASSWORD 
docker build . -t $DOCKER_IMAGE_SCOPE
docker push ${DOCKER_HOST}/${DOCKER_IMAGE_SCOPE}