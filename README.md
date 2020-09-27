# 0. Prerrequisitos
```
sudo apt update && sudo apt upgrade
sudo apt install net-tools curl
```
Puede ser necesario reducir el swap para que funcione Kubernetes; de lo contrario, podría no arrancar al reiniciar el sistema. Abrimos el archivo `/etc/fstab` (con sudo), comentamos la línea con el swap y reinicamos. Para desactivarlo **SÓLO** en la sesión actual ejecutamos* `sudo swapoff -a`.

# 1. OSM

## 1.1 Instalación
```
wget https://osm-download.etsi.org/ftp/osm-8.0-eight/install_osm.sh
chmod +x install_osm.sh
./install_osm.sh --vimemu
```
**La opción `--vimemu` parece no funcionar correctamente, con lo que puede que haya que instalarlo manualmente (contruir la imagen para el contenedor), ver más abajo la sección correspondiente**
El container framework por defecto es Swarm, que es el que se utiliza porque Kubernetes da problemas de incompatibilidad con Microk8s (habría que usar la opción `-c k8s`)  
`--k8s_monitor` instala una herramienta de monitorización del clúster para OSM si se utiliza Kubernetes como container framework  
`--vimemu` instala vimemu  

### Versiones
- Docker: 19.03.12
- Kubernetes: 1.15.12

### Problemas
- Fallo en Juju si la instalación ya se intentó pero no se completó
LOG:    `Finished installation of juju`
        `ERROR controller "osm" already exists`
FIX 1:  `juju unregister -y osm`
FIX 2:  `juju destroy-controller osm --destroy-all-models -y`
- No funciona Kubernetes (por ejemplo, `kubectl -n osm get all` da error)
FIX:    Desactivar swap (ver más arriba)

Para otros errores comunes que puedan surgir: https://osm.etsi.org/wikipub/index.php/Common_issues_and_troubleshooting.

## 1.2 Comandos útiles
- Para comprobar el estado de los contenedores que forman OSM, utilizar `docker stack ps osm | grep -i running` o `docker service ls` (si se utilizar el framework de Kubernetes, sería `kubectl -n osm get all`).  
- Para reinciar los contenedores, se utilizaría `docker stack rm osm && sleep 60` y luego `docker stack deploy -c /etc/osm/docker/docker-compose.yaml osm`.
- Para ejecutar `docker` sin necesidad de sudo:
```
sudo usermod -aG docker `whoami`
newgrp docker 
```

# 2. Vim-emu

## 2.1 Instalación
*No es necesario si se instala con OSM*
```
git clone https://osm.etsi.org/gerrit/osm/vim-emu.git
docker build -t vim-emu-img ./vim-emu
```

## 2.2 Despliegue sobre OSM
Instanciamos un contenedor con vim-emu (si no existe ya):
```
docker run --name vim-emu -t -d --rm --privileged --pid='host' --netowork=netosm -v /var/run/docker.sock:/var/run/docker.sock vim-emu-img python examples/osm_default_daemon_topology_2_pop.py
export VIMEMU_HOSTNAME=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' vim-emu)
```
Añadimos a OSM la instancia de vim-emu, que simula una infraestructura gestionada con Openstack:
```
osm vim-create --name emu-vim1 --user username --password password --auth_url http://$VIMEMU_HOSTNAME:6001/v2.0 --tenant tenantName --account_type openstack
```

# 3. Microk8s

## 3.1 Instalación
```
sudo snap install microk8s --classic
microk8s.status --wait-ready
microk8s.enable storage dns
microk8s.config | cat - > kubeconfig.yaml
```

## 3.2 Despliegue sobre OSM
Añadimos a OSM el cluster:
```
osm k8scluster-add --creds kubeconfig.yaml --version '1.18' --vim emu-vim1 --description "My K8s cluster" --k8s-nets '{"net1": "osm-ext"}' microk8s-cluster
```

## 3.3 Comandos útiles
Para ejecutar `microk8s` sin necesidad de sudo:
```
sudo usermod -aG microk8s `whoami`
newgrp microk8s
```

# 4. VNF: nginx
Como ejemplo, se despliega mediante un Helm Chart una VNF que simula un servidor nginx, con lo que mediante un acceso al navegador podemos comprobar que la OSM y todos sus componentes funcionan completamente. Además, los archivos que describen esta VNF se hallan en un repositorio de Helm Charts en GitHub.  

## 4.1 Añadido del repositorio a OSM
```
osm repo-add --type helm-chart --description mygitrepo mygitrepo https://gabrielfdosreis.github.io/helm-chart
```

## 4.2 Despliegue
Creamos la VNF y el NS:
```
osm nfpkg-create nginx_vnfd.yaml
osm nspkg-create nginx_nsd.yaml
```

Instanciamos el NS:
```
osm ns-create --ns_name nginx --nsd_name nginx_ns --vim_account emu-vim1
```

## 4.3 Comprobación
Desde la interfaz web de OSM, accedemos a *Instances --> NS Instances* y pulsamos el botón de información de la instancia creada. Buscamos el namespace de Microk8s, bajo la etiqueta *"projects_write"* o *"projects_read"*. Para obtener la IP desde la que se está accesible el servicio, ejecutamos el comando `microk8s kubectl get service --namespace=...` y comprobamos desde el navegador que el servidor web Nginx está funcionando. El comando `get service` se puede cambiar por otros como `get pods` para obtener más información sobre el servicio.  

# A. Creación del repositorio de Helm charts
*Puede ser necesario instalar helm con `sudo snap install helm`.*  
  
Desde la carpeta del repositorio (que puede estar ya inicializado en GitHub o inicializarlo localmente para posteriormente hacer push), creamos una carpeta para incluir el contenido de los charts (no es estrictamente necesario, ya que Helm descarga el chart completo en formato .tgz pero es recomendable):
```
mkdir helm-chart-sources
```

Para crear un chart de prueba:
```
helm create helm-chart-sources/nginx
```

Para crear el paquete del chart:
```
helm package helm-chart-sources/nginx
```

Para crear (o actualizar) el index del repo, donde se encuentran listados todos los charts que contiene:
```
helm repo index --url https://user.github.io/helm-chart-repo .
helm repo index --url https://user.github.io/helm-chart-repo --merge index.yaml .
```

En el repositorio, ir a *Configuración --> GitHub Pages --> Source > Master branch* para crear un GitHub Pages, que actúa como servidor web que permite la descarga de archivos del repositorio.  
Añadir el repositoiro al cliente Helm (**indicando la URL de GitHub Pages**):
```
helm repo add myhelmrepo https://user.github.io/helm-chart-repo
```

**!!!!ERRROR APIVERSION**
**Service accounts???**
Detail: Deploying at VIM: Error at VIM network 'nsd-vld-id=mgmtnet':
    Invalid URL or credentials: Unable to establish connection to http://10.0.1.45:6001/v2.0/tokens:
    HTTPConnectionPool(host='10.0.1.45', port=6001): Max retries exceeded with url: /v2.0/tokens
    (Caused by NewConnectionError(': Failed to establish a new connection: [Errno 113] No route to host',))
--> comprobar vimemu
  
osm nfpkg-create NFV-LAB-2019/vnf-vclass.yaml && osm nfpkg-create NFV-LAB-2019/vnf-vcpe.yaml && osm nspkg-create NFV-LAB-2019/ns-vcpe.yaml && osm ns-create --ns_name vcpe-1 --nsd_name vCPE --vim_account emu-vim1  

# B. Debug: despliegue local del chart para comprobar el funcionamiento
Con estos comandos podemos desplegar el Helm Chart en el Helm local sobre un Kubernetes para comprobar que está definido correctamente y que funciona sin problemas:
```
export KUBECONFIG=/home/gabriel/osm/kubeconfig.yaml
helm install nginx/ --values nginx/values.yaml -n nginx-0.1.0
helm install name repo/chart
export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
export NODE_PORT=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services nginx-0.1.0)
echo http://$NODE_IP:$NODE_PORT
```

Para eliminarlo:
```
helm remove nginx-0.1.0
```

## Comandos útiles (Helm)
Para buscar un chart en un repo:
```
helm search chart
```

Para comprobar si los charts están definidos correctamente:
```
helm lint helm-chart-sources/chart
```