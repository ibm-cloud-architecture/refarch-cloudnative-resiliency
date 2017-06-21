###### refarch-cloudnative-mysql

This database will be managed by refarch-cloudnative-micro-inventory microservice.

### Setup Inventory Database on Local MySQL Container
1. Clone git repository. If you cloned the peer repositories **`./clonePeers.sh`**, then you should not do a *`git clone`*
    ```
    # git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-mysql.git
    # cd refarch-cloudnative-mysql
    ```

2. Create MySQL container with database `inventorydb`. This database can be connected at `<docker-host-ipaddr/hostname>:3306` as `dbuser` using `password`.
    ```
    Linux/macOS:
    # docker run --name mysql -v $PWD/scripts:/home/scripts -p 3306:3306 -e MYSQL_ROOT_PASSWORD=admin123 -e MYSQL_USER=dbuser -e MYSQL_PASSWORD=password -e MYSQL_DATABASE=inventorydb -w /home/scripts -d mysql:latest
    ```
    ```
    Windows:
    # docker run --name mysql -v %CD%\scripts:/home/scripts -p 3306:3306 -e MYSQL_ROOT_PASSWORD=admin123 -e MYSQL_USER=dbuser -e MYSQL_PASSWORD=password -e MYSQL_DATABASE=inventorydb -w /home/scripts -d mysql:latest
    ```


3. Create `items` table and load sample data.
    ```
    # docker exec -it mysql sh load-data.sh
    ```

4. Verify, there should be 12 rows in the table.
    ```
    # docker exec -it mysql bash
    # mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}
    mysql> select * from items;
    mysql> quit
    # exit
    ```

Inventory database is now setup in local container.

### Setup Inventory Database in IBM Bluemix container
1. Clone git repository. If you cloned the peer repositories **`./clonePeers.sh`**, then you should not do a *`git clone`*
    ```
    # git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-mysql.git
    ```

2. Change to the directory of the repository.
    ```
    # cd refarch-cloudnative-mysql
    ```

2. Build docker image using the Dockerfile from repo.
    ```
    # docker build -t cloudnative/mysql .
    ```

3. Log in to your Bluemix account.
    ```
    # cf login -a <bluemix-api-endpoint> -u <your-bluemix-user-id>
    ```

4. Set target to use your Bluemix Org and Space.
    ```
    # cf target -o <your-bluemix-org> -s <your-bluemix-space>
    ```

5. Log in to IBM Containers plugin.
    ```
    # cf ic login
    ```

5. Check that your organization has set a namespace.
    ```
    # cf ic namespace get
    ```

5. If there is no namespace set for your , then set a namespace.
    ```
    # cf ic namespace get
    ```

4. Tag and push mysql database server image to your Bluemix private registry namespace.
    ```
    # docker tag cloudnative/mysql registry.ng.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    # docker push registry.ng.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    ```

5. Create MySQL container with database `inventorydb`. This database can be connected at `<docker-host-ipaddr/hostname>:3306` as `dbuser` using `Pass4dbUs3R`.

    _It is recommended to change the default passwords used here._
    ```
    # cf ic run -m 512 --name mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=Pass4Admin123 -e MYSQL_USER=dbuser -e MYSQL_PASSWORD=Pass4dbUs3R -e MYSQL_DATABASE=inventorydb registry.ng.bluemix.net/$(cf ic namespace get)/mysql:cloudnative
    ```

6. Create `items` table and load sample data. You should see message _Data loaded to inventorydb.items._
    ```
    # cf ic exec -it mysql sh load-data.sh
    ```

7. Verify, there should be 12 rows in the table.
    ```
    # cf ic exec -it mysql bash
    # mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}
    mysql> select * from items;
    mysql> quit
    # exit
    ```

Inventory database is now setup in IBM Bluemix Container.
