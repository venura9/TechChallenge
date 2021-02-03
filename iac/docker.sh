#/bin/bash

DOCKER_HOST=$(terraform output docker_host)
DOCKER_HOST=$(sed -e 's/^"//' -e 's/"$//' <<< $DOCKER_HOST)

DOCKER_USER=$(terraform output docker_user)
DOCKER_USER=$(sed -e 's/^"//' -e 's/"$//' <<< $DOCKER_USER)

DOCKER_PASSWORD=$(terraform output docker_password)
DOCKER_PASSWORD=$(sed -e 's/^"//' -e 's/"$//' <<< $DOCKER_PASSWORD)

DOCKER_IMAGE_SCOPE=$(terraform output docker_image_scope)
DOCKER_IMAGE_SCOPE=$(sed -e 's/^"//' -e 's/"$//' <<< $DOCKER_IMAGE_SCOPE)

DB_HOST=$(terraform output db_host)
DB_HOST=$(sed -e 's/^"//' -e 's/"$//' <<< $DB_HOST)

DB_USER=$(terraform output db_user)
DB_USER=$(sed -e 's/^"//' -e 's/"$//' <<< $DB_USER)

DB_PASSWORD=$(terraform output db_password)
DB_PASSWORD=$(sed -e 's/^"//' -e 's/"$//' <<< $DB_PASSWORD)

DB_NAME=$(terraform output db_name)
DB_NAME=$(sed -e 's/^"//' -e 's/"$//' <<< $DB_NAME)

cd ..

# docker login https://${DOCKER_HOST}/v2/ -u $DOCKER_USER -p $DOCKER_PASSWORD 
docker login $DOCKER_HOST -u $DOCKER_USER -p $DOCKER_PASSWORD 
docker build . -t $DOCKER_IMAGE_SCOPE
docker push ${DOCKER_HOST}/${DOCKER_IMAGE_SCOPE}

export VTT_DBHOST=$DB_HOST
export VTT_DBUSER=$DB_USER
export VTT_DBPASSWORD=$DB_PASSWORD
export VTT_DBNAME=$DB_NAME

echo "docker run -it -e VTT_DBHOST -e VTT_DBUSER -e VTT_DBPASSWORD -e VTT_DBNAME ${DOCKER_IMAGE_SCOPE} updatedb -s"