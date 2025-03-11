# podsys-lite-core
**Monitor the deployment progress of podsys**

## Build in Docker(recommend)
**The size of the packaged file is smaller using this method**
### Create container
``` shell
docker run --name podsys-lite-core --privileged=true -it  -v ${PWD}:/podsys-lite-core  ubuntu:22.04 /bin/bash
```
### install env in container
``` shell
apt update
apt install python3
apt install python3-pip
apt install upx
pip install Flask
pip install psutil
pip install pyinstaller
cd /podsys-lite-core
```

### build
``` shell
pyinstaller --onefile --add-data "templates:templates" --add-data "static:static" --upx-dir=/usr/bin/upx --strip --clean --name podsys-lite-core --exclude-module wheel --exclude-module PyGObject --exclude-module pyinstaller --exclude-module pipdeptree app.py
```

### test
``` shell
cd dist
./podsys-lite-core
```
