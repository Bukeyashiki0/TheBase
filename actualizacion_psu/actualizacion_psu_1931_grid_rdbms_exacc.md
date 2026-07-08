# Actualización de PSU a 19.31 — Grid Infrastructure y RDBMS en Exadata Cloud@Customer (ExaCC)

**Versión del documento:** 1.0
**Fecha:** Julio 2026
**Objetivo:** Actualizar el Grid Infrastructure (GI) y el software de base de datos (RDBMS) a la versión **19.31.0.0.0** (RU de abril de 2026) usando `dbaascli`, para cumplir el requisito del equipo de Linux/Sistemas de estar en **19.24 o superior** antes del parcheo de sistema operativo.

---

## 1. Convenciones usadas en este documento

Este documento es **neutro**: sirve para cualquier par de nodos del clúster. Se usan los nombres del entorno de práctica (PRO); sustitúyelos por los del entorno que toque.

| Marcador en el documento | Significado | Valor en el entorno de práctica |
|---|---|---|
| `nodo1` | Primer nodo del clúster | `c3cto1gscpro01-1` |
| `nodo2` | Segundo nodo del clúster | `c3cto1gscpro01-2` |
| `<DB_NAME>` | Nombre de la base de datos (DB unique name) | El que exista en el entorno (ver cómo obtenerlo en 2.2) |
| `<HOME_NUEVO>` | Ruta del nuevo Oracle Home 19.31 | Se obtiene en la Fase 5 (ej. `/u02/app/oracle/product/19.0.0.0/dbhome_2`) |
| `<HOME_VIEJO>` | Ruta del Oracle Home actual | Se obtiene en la Fase 2 |

**Usuarios del sistema operativo que se usan:**

- `root` — casi todos los comandos `dbaascli` se ejecutan como root.
- `grid` — propietario del Grid Infrastructure. Se accede con `sudo su - grid` desde root.
- `oracle` — propietario del software de base de datos. Se accede con `sudo su - oracle` desde root.

**Cómo leer los bloques de comandos:** el prompt indica el usuario y el nodo. Por ejemplo, `[root@nodo1 ~]#` significa "conectado como root en el nodo1". Ejecuta solo lo que va después del `#` o `$`.

**Regla de oro:** si un comando falla o muestra `FATAL` o `ERROR`, **detente**, guarda la salida completa y el fichero de log que indica el propio comando, y revisa la causa antes de continuar. No improvises. Los `WARNING` se leen, se anotan y normalmente permiten continuar (en este documento se indica cuáles son esperables).

---

## 2. Resumen de fases y tiempos estimados

| Fase | Descripción | Tiempo estimado | ¿Corte de servicio? |
|---|---|---|---|
| 0 | Preparación previa (accesos, descargas, WinSCP) | 1 – 2 h | No |
| 1 | Actualización de herramientas (dbaascli, AHF, CVU, exachk) | 1 – 1,5 h | No |
| 2 | Estado inicial del clúster y prechequeos (exachk) | 1 – 1,5 h | No |
| 3 | Descarga de las imágenes 19.31 (GI y BBDD) al nodo | 30 – 60 min | No |
| 4 | Parcheo del Grid Infrastructure a 19.31 (rolling, nodo a nodo) | 2 – 4 h | No (rolling; cada nodo se para de uno en uno) |
| 5 | Creación del nuevo Oracle Home RDBMS 19.31 | 45 – 90 min | No |
| 6 | Mover la BBDD al nuevo home (database move + datapatch) | 1 – 2 h | Parcial (rolling instancia a instancia) |
| 7 | Verificaciones finales y cierre | 30 – 45 min | No |

**Total estimado: 8 – 12 horas.** Puede repartirse en varios días: las fases 0–3 pueden hacerse días antes de la ventana; las fases 4–7 dentro de la ventana de cambio (CHG). En un entorno con carga real, las fases 4 y 6 se hacen siempre dentro de ventana aprobada.

---

## Fase 0 — Preparación previa

**Tiempo estimado: 1 – 2 horas** (depende de las descargas).

### 0.0 Datos de esta ejecución (rellenar antes de empezar)

```text
✍ Fecha de ejecución:      
✍ Ejecutado por:           
✍ Entidad / entorno:       
✍ Número de CHG:           
✍ nodo1 (nombre real):     
✍ nodo2 (nombre real):     
```

### 0.1 Qué necesitas antes de empezar

1. **Acceso SSH como root a los dos nodos** (`nodo1` y `nodo2`). Compruébalo conectándote a ambos.
2. **Cuenta de My Oracle Support (MOS)** con permisos de descarga: <https://support.oracle.com>
3. **WinSCP instalado en tu PC** para subir ficheros a los nodos.
4. **Número de cambio (CHG) aprobado** si es un entorno con servicio (en el entorno de práctica no aplica).
5. Confirmar con el equipo que **no hay backups, cargas ni procesos batch** planificados durante la ventana.

### 0.2 Software a descargar en tu PC

Descarga estos ficheros en tu ordenador. Después se subirán por WinSCP a los nodos (se indica en cada fase a qué ruta).

| # | Software | Dónde descargarlo | Fichero aproximado |
|---|---|---|---|
| 1 | **AHF (Autonomous Health Framework)** — incluye TFA y exachk | MOS, Doc ID **2550798.1** ("Autonomous Health Framework (AHF) - Including TFA and ORAchk/EXAchk"). Descarga la última versión para **Linux x86-64** | `AHF-LINUX_vXX.X.X.zip` |
| 2 | **CVU (Cluster Verification Utility)** — última versión | Página oficial: <https://www.oracle.com/database/technologies/cvu-downloads.html> (enlaza al parche MOS **30839369**). Elegir plataforma **Linux x86-64** | `cvupack_linux_ol7_x86_64.zip` (o similar) |

> **Nota:** las **imágenes de GI y RDBMS 19.31 NO se descargan de internet**. Las descarga el propio nodo desde el repositorio de Oracle Cloud con `dbaascli cswlib download` (Fase 3). El propio `dbaascli` también se actualiza solo desde el repositorio (Fase 1). Solo AHF y CVU se suben a mano.

### 0.3 Subir los ficheros a los nodos con WinSCP

1. Abre WinSCP, protocolo **SFTP**, host `nodo1`, usuario con el que entras por SSH.
2. Sube los dos ZIP (AHF y CVU) al directorio **`/tmp`** del nodo1.
3. Repite la subida al **`/tmp` del nodo2** (ambos nodos necesitan los dos ficheros).
4. Verifica en cada nodo que los ficheros están y su tamaño coincide con el descargado:

```bash
[root@nodo1 ~]# ls -lh /tmp/AHF-LINUX_v*.zip /tmp/cvupack*.zip
[root@nodo2 ~]# ls -lh /tmp/AHF-LINUX_v*.zip /tmp/cvupack*.zip
```

### 0.4 Abrir sesiones de trabajo

Recomendación: abre **dos terminales por nodo** (una para lanzar comandos, otra para mirar logs) y activa el registro de sesión de tu cliente SSH (en PuTTY: *Session → Logging*), para conservar evidencia de todo lo ejecutado.

---

## Fase 1 — Actualización de las herramientas

**Tiempo estimado: 1 – 1,5 horas.**
Sin impacto en servicio. Se puede hacer días antes de la ventana.

Orden dentro de la fase: primero `dbaascli` (porque es la herramienta que orquesta todo lo demás), después AHF, después CVU.

### 1.1 Actualizar dbaascli (las "tools" de cloud)

**Ejecutar en: nodo1** (el comando de actualización actualiza los dos nodos a la vez, como se ve en su log: pasos `Rpm_local_installation` y `Rpm_remote_installation`).

**Paso 1 — Ver qué versión hay instalada** (en ambos nodos, para tener la foto inicial):

```bash
[root@nodo1 ~]# rpm -qa | grep -i dbaastools_exa
dbaastools_exa-1.0-1+XX.X.X.X.X_XXXXXX.XXXX.x86_64
```

```text
✍ Versión dbaastools ANTES  — nodo1:   nodo2: 
```

**Paso 2 — Comprobar la última versión publicada por Oracle:**

```bash
[root@nodo1 ~]# dbaascli admin showLatestStackVersion
```

- Compara el campo `version` de la salida con la versión instalada del paso 1: si coinciden, ya estás al día → salta al punto 1.2.

> **Nota:** en versiones antiguas de las tools esta comprobación se hacía con `dbaascli patch tools list`. En dbaascli 26.x ese comando está obsoleto (`[INFO] [DBAAS-14011] deprecated`) y falla con `An error occurred during module execution`: es esperable, no lo uses; usa el de arriba.

**Paso 3 — Actualizar el stack de herramientas:**

```bash
[root@nodo1 ~]# dbaascli admin updateStack
```

- El comando muestra una lista larga de "jobs" (`Running ...` / `Completed ...`). Es normal que muchos digan `Skipping. Job is detected as not applicable.`
- Si la versión ya estuviera instalada, verás `[WARNING] [DBAAS-70212] The target rpm version ... is already installed` — es informativo, no es un error.
- Duración típica: 10 – 20 minutos.
- El log queda en `/var/opt/oracle/log/tooling/Update/`.

**Paso 4 — Verificar en ambos nodos que quedó la misma versión:**

```bash
[root@nodo1 ~]# rpm -qa | grep -i dbaastools_exa
[root@nodo2 ~]# rpm -qa | grep -i dbaastools_exa
```

La versión del rpm debe ser idéntica en los dos nodos y coincidir con la publicada en el paso 2. Si los nodos quedan con versiones distintas, **no continúes**: repite el `updateStack` y revisa el log hasta igualarlas.

```text
✍ Versión dbaastools DESPUÉS (ambos nodos): 
```

### 1.2 Actualizar AHF (incluye TFA y exachk)

**Ejecutar en: ambos nodos, de uno en uno** (primero nodo1, luego nodo2).

**Paso 1 — Ver la versión actual y el estado:**

```bash
[root@nodo1 ~]# ahfctl version
AHF version: XX.X.X

[root@nodo1 ~]# ahfctl statusahf
```

`statusahf` debe mostrar los dos nodos con TFA en estado `RUNNING`. Que diga `exachk daemon is not running` es normal (exachk se lanza a demanda).

```text
✍ Versión AHF ANTES — nodo1:   nodo2: 
```

**Paso 2 — Comparar con la última versión disponible** en MOS Doc ID 2550798.1. Si la instalada es igual a la descargada, salta al punto 1.3.

**Paso 3 — Instalar/actualizar AHF** con el ZIP subido en la Fase 0:

```bash
[root@nodo1 ~]# mkdir -p /tmp/ahf_instalacion
[root@nodo1 ~]# cd /tmp/ahf_instalacion
[root@nodo1 ahf_instalacion]# unzip -o /tmp/AHF-LINUX_v*.zip
[root@nodo1 ahf_instalacion]# ./ahf_setup -local
```

- El instalador **detecta la instalación existente y la actualiza** conservando la configuración. Si pregunta si quieres hacer upgrade, responde `Y`.
- La opción `-local` limita la instalación al nodo actual; por eso hay que repetirlo en el nodo2.
- Duración típica: 10 – 15 minutos por nodo.

**Paso 4 — Verificar:**

```bash
[root@nodo1 ~]# ahfctl version
[root@nodo1 ~]# ahfctl statusahf
[root@nodo1 ~]# exachk -v
```

La versión de `ahfctl version` debe ser la nueva y TFA debe quedar `RUNNING` en ambos nodos.

**Paso 5 — Repetir los pasos 1–4 en el nodo2.**

```text
✍ Versión AHF DESPUÉS — nodo1:   nodo2: 
```

### 1.3 Actualizar CVU (Cluster Verification Utility)

**Ejecutar en: ambos nodos.**

CVU no se "instala": basta con dejar el ZIP en la ruta donde AHF/exachk lo busca.

```bash
[root@nodo1 ~]# cp /tmp/cvupack_linux_*.zip /opt/oracle.ahf/common/cvu/
[root@nodo1 ~]# ls -ltr /opt/oracle.ahf/common/cvu/
```

Debe verse el ZIP con el tamaño correcto. Repite exactamente lo mismo en el nodo2.

> Elige la versión de CVU compatible con base de datos **19c** (la página de descargas lo indica; la versión CVU 21+ es válida para 19c).

### 1.4 Nota sobre patchmgr (dbserver patch)

El documento antiguo descargaba también `patchmgr` (`/opt/exacloud/exadata_updates/exadata_updates.sh -get patchmgr`). Ese software lo usa el **equipo de Linux/Sistemas** para parchear el sistema operativo de los nodos, **después** de nuestro trabajo. **No es necesario para actualizar GI/RDBMS.** Solo descárgalo si el equipo de Linux lo pide expresamente, y limítate a descargarlo (no lo ejecutes).

---

## Fase 2 — Estado inicial del clúster y prechequeos

**Tiempo estimado: 1 – 1,5 horas** (el informe exachk tarda 20 – 40 min).
Sin impacto en servicio.

El objetivo es fotografiar el estado ANTES de tocar nada. Guarda todas las salidas de esta fase.

### 2.1 Estado general del clúster

**En nodo1, como root:**

```bash
[root@nodo1 ~]# su - grid
(grid@nodo1)$ crsctl check cluster -all
```

Los dos nodos deben mostrar `CRS-4537`, `CRS-4529` y `CRS-4533` (Cluster Ready Services, Cluster Synchronization Services y Event Manager **online**).

```bash
(grid@nodo1)$ crsctl stat res -t
```

Revisa que los recursos (ASM, listener, base de datos) estén `ONLINE` en ambos nodos.

**Procesos de instancia levantados (en ambos nodos):**

```bash
[root@nodo1 ~]# ps -ef | grep pmon
```

Debe verse al menos `asm_pmon_+ASM1` (o `+ASM2` en nodo2) y el pmon de cada instancia de BBDD, p. ej. `ora_pmon_<DB_NAME>1`.

### 2.2 Versiones actuales de GI y RDBMS

**Versión de GI/ASM (como grid, en nodo1):**

```bash
(grid@nodo1)$ crsctl query crs activeversion -f
Oracle Clusterware active version on the cluster is [19.0.0.0.0]. The cluster upgrade state is [NORMAL]. ...

(grid@nodo1)$ asmcmd showversion
(grid@nodo1)$ $ORACLE_HOME/OPatch/opatch lspatches
```

Anota: el estado del clúster debe ser **[NORMAL]** (si dice `ROLLING PATCH` es que hay un parcheo a medias: **no continúes** hasta completarlo) y la versión de RU actual de la línea `Database Release Update : 19.XX...`.

```text
✍ Estado del clúster:              (debe ser NORMAL)
✍ Versión GI/RU actual (ANTES):    (p. ej. 19.27.0.0.0 — es la
                                                   <version_anterior> del Anexo A)
```

**Homes de RDBMS instalados y BBDD que contienen (como root, en nodo1):**

```bash
[root@nodo1 ~]# dbaascli dbHome getDetails
```

(Si tu versión no lo soporta, el equivalente antiguo es `dbaascli dbhome info`, pulsando Intro cuando pregunta por el nombre del home.)

Anota para cada home: `HOME_LOC`, `VERSION` y `DBs installed`. El home que tenga la BBDD instalada es tu `<HOME_VIEJO>`.

```text
✍ <HOME_VIEJO>:            
✍ Versión RDBMS actual:    
✍ <DB_NAME>:               
```

**Nombre de la base de datos:** el campo `DBs installed` del comando anterior es el `<DB_NAME>` que se usará en la Fase 6. Confírmalo con:

```bash
[root@nodo1 ~]# su - oracle
(oracle@nodo1)$ srvctl config database
```

(Lista los nombres de BBDD registrados en el clúster.)

**Parches del home de BBDD actual (como oracle):**

```bash
(oracle@nodo1)$ $ORACLE_HOME/OPatch/opatch lspatches -oh <HOME_VIEJO>
```

### 2.3 Espacio en disco

**Filesystem del GI (como grid):**

```bash
(grid@nodo1)$ df -h /u01/app/19.0.0.0/grid
```

Se recomienda al menos **15 – 20 GB libres** en el filesystem del grid home.

**Filesystem de los homes de BBDD y ACFS (como root):**

```bash
[root@nodo1 ~]# df -h /u02
[root@nodo1 ~]# df -h /acfs01
```

La imagen de BBDD ocupa en torno a **35 GB en el ACFS** (`/var/opt/oracle/dbaas_acfs`); comprueba que `/acfs01` tiene al menos 50 GB libres. Repite las comprobaciones en el nodo2.

### 2.4 Informe exachk (chequeo de mejores prácticas)

**En nodo1, como root** (exachk se ejecuta desde un nodo y recoge datos de los dos):

```bash
[root@nodo1 ~]# exachk
```

- Cuando pregunte qué bases de datos chequear, selecciona `1` (todas / la que exista).
- Tarda **20 – 40 minutos**. Al final indica la ruta de un informe HTML, p. ej.:
  `/u01/app/grid/oracle.ahf/data/<nodo1>/exachk/user_root/output/exachk_..._.html`
- Descárgate el HTML por WinSCP y revísalo.

```text
✍ Ruta del informe exachk:  
✍ FAIL/CRITICAL a revisar:  
```

**Cómo interpretar el informe:**

- `FAIL` / `CRITICAL` relacionados con **clusterware, ASM, espacio, parches de GI/RDBMS** → deben resolverse **antes** de parchear.
- `CRITICAL` de tipo "ksplice fixes should be installed" o "Exadata critical issue EXxx" → suelen ser del ámbito del **equipo de Linux/Sistemas**; repórtalos pero no bloquean este cambio (consúltalo si hay duda).
- `WARNING` / `INFO` de mejores prácticas de BBDD (Data Guard, RMAN, parámetros) → se anotan; no bloquean.

---

## Fase 3 — Descarga de las imágenes 19.31 en el nodo

**Tiempo estimado: 30 – 60 minutos** (depende del ancho de banda al repositorio de Oracle).
Sin impacto en servicio. Ejecutar en **nodo1** como root.

### 3.1 Ver las imágenes disponibles

**Imágenes de Grid:**

```bash
[root@nodo1 ~]# dbaascli cswlib showImages --product grid
```

Debe aparecer la 19.31:

```text
5.IMAGE_TAG=grid_19.31.0.0.0
  VERSION=19.31.0.0.0
  DESCRIPTION=19c APR 2026 GI Image
  IMAGE_ALIASES=grid_19.31.0.0.0.260421
```

**Imágenes de base de datos:**

```bash
[root@nodo1 ~]# dbaascli cswlib showImages --product database
```

Localiza la entrada 19.31 (19c APR 2026 DB Image) y **anota su IMAGE_TAG exacto** tal y como lo muestra tu sistema.

```text
✍ IMAGE_TAG BBDD 19.31:         ✍ IMAGE_TAG grid 19.31: 
```

### 3.2 Descargar la imagen de base de datos 19.31

Con el IMAGE_TAG anotado:

```bash
[root@nodo1 ~]# dbaascli cswlib download --product database --imageTag 19.31.0.0.0
```

> Alternativa con la sintaxis del documento antiguo (equivalente): `dbaascli cswlib download --version 19000 --bp APR2026 --cdb yes` — 19.31 corresponde al bundle patch **APR2026**.

La descarga deja la imagen en el ACFS (`/var/opt/oracle/dbaas_acfs`). Verifica después:

```bash
[root@nodo1 ~]# dbaascli dbimage list
```

Debe aparecer `APR2026 (For DB Versions 19000)` en la lista de imágenes disponibles, y el `df -h` del ACFS que imprime el propio comando debe seguir mostrando espacio libre.

### 3.3 Imagen de Grid

**No hace falta descargarla a mano:** el comando `dbaascli grid patch` la descarga automáticamente durante el job `download_patches` (Fase 4). Si prefieres dejarla descargada antes de la ventana (recomendable para acortar la ventana), ejecuta:

```bash
[root@nodo1 ~]# dbaascli cswlib download --product grid --imageTag grid_19.31.0.0.0
```

(usa el IMAGE_TAG exacto que mostró `showImages --product grid`).

---

## Fase 4 — Parcheo del Grid Infrastructure a 19.31

**Tiempo estimado: 2 – 4 horas** (prerrequisitos 20 – 40 min; 60 – 90 min por nodo; verificaciones).
**Impacto:** es **rolling**: se parchea un nodo cada vez. Mientras se parchea un nodo, sus instancias (ASM y BBDD) se paran en ese nodo y el servicio queda en el otro. No hay corte total si las aplicaciones toleran la caída de una instancia.

> **Muy importante:** el parcheo de grid con `--nodeList` se ejecuta **en el propio nodo que se está parcheando** (como root). Si intentas parchear el nodo2 lanzando el comando desde el nodo1, falla con `[FATAL] [DBAAS-70064] Specified cluster nodes '[nodo2]' does not include local node name 'nodo1'` (está comprobado en el documento antiguo).

### 4.1 Pasar los prerrequisitos

**En nodo1, como root:**

```bash
[root@nodo1 ~]# dbaascli grid patch --targetVersion 19.31.0.0.0 --executePrereqs
```

- Ejecuta una batería de validaciones (`validate_nodes`, `validate_disk_space`, `check_patch_conflicts`, etc.) y descarga/desempaqueta el parche. No toca el clúster.
- Debe terminar con `Grid Patching Prereqs Execution Successful.`
- Si algún job falla, mira el log que indica (`/var/opt/oracle/log/gridPatch/...`), corrige la causa (habitualmente espacio en disco) y vuelve a lanzarlo. **No sigas con un prereq fallido.**

### 4.2 Parchear el nodo1

**En nodo1, como root:**

```bash
[root@nodo1 ~]# dbaascli grid patch --targetVersion 19.31.0.0.0 --nodeList c3cto1gscpro01-1
```

- Verás el WARNING esperado `[DBAAS-70139] A subset of nodes ... has been passed. ACTION: Make sure to complete patching on rest of the nodes soon.` — es normal: le estamos diciendo que solo parchee este nodo.
- El proceso hace backup de la imagen del home, para las instancias del nodo (`stop_db_instances`), aplica la RU (`apply_ru`), ejecuta el postpatch y vuelve a levantar las instancias (`start_db_instances`).
- Duración típica: **60 – 90 minutos**. No cierres la sesión (usa `screen`/`tmux` si está disponible, o no toques la terminal).
- Debe terminar con `Grid Patching Successful.`
- Log de seguimiento (en la otra terminal): `tail -f` del fichero que indica en `Log file location: /var/opt/oracle/log/gridPatch/pilot_...`

### 4.3 Verificar el nodo1

**Como grid en nodo1:**

```bash
[root@nodo1 ~]# su - grid

(grid@nodo1)$ $ORACLE_HOME/OPatch/opatch lspatches
```

Debe aparecer `Database Release Update : 19.31.0.0.XXXXXX` y el `ACFS RELEASE UPDATE 19.31.0.0.0`.

```bash
(grid@nodo1)$ crsctl query crs activeversion -f
```

En este punto el estado será **`[ROLLING PATCH]`** — es lo esperado: indica que falta el otro nodo.

```bash
(grid@nodo1)$ asmcmd showversion --softwarepatch
(grid@nodo1)$ ps -ef | grep pmon
```

ASM debe reportar 19.31.0.0.0 y los procesos pmon (ASM + instancia de BBDD) deben estar de nuevo levantados en el nodo1. **No pases al nodo2 hasta que las instancias del nodo1 estén arriba.**

```text
✍ Grid nodo1 — hora inicio:   hora fin: 
✍ Log PILOT nodo1:          
```

### 4.4 Parchear el nodo2

**Conéctate por SSH al nodo2** y ejecuta como root:

```bash
[root@nodo2 ~]# dbaascli grid patch --targetVersion 19.31.0.0.0 --nodeList c3cto1gscpro01-2
```

Mismo comportamiento y duración que en el nodo1 (60 – 90 min). Debe terminar con `Grid Patching Successful.`

```text
✍ Grid nodo2 — hora inicio:   hora fin: 
✍ Log PILOT nodo2:          
```

### 4.5 Verificar el clúster completo

**Como grid, en cualquiera de los dos nodos:**

```bash
(grid@nodo2)$ $ORACLE_HOME/OPatch/opatch lspatches
(grid@nodo2)$ crsctl query crs activeversion -f
```

Ahora el estado debe ser **`[NORMAL]`**. Si sigue en `ROLLING PATCH`, algún nodo no terminó bien: revisa sus logs antes de continuar.

```bash
(grid@nodo2)$ crsctl query crs releasepatch
(grid@nodo2)$ asmcmd showversion --softwarepatch
(grid@nodo2)$ ps -ef | grep pmon
(grid@nodo2)$ crsctl check cluster -all
```

Comprueba en **ambos nodos**: mismos parches en `opatch lspatches`, ASM en 19.31.0.0.0, clúster online y pmon levantados.

**✔ Hito:** el Grid ya está en 19.31 (≥ 19.24, requisito del equipo de Linux cumplido para el GI).

---

## Fase 5 — Creación del nuevo Oracle Home RDBMS 19.31

**Tiempo estimado: 45 – 90 minutos.**
Sin impacto en servicio: se instala un home **nuevo** sin tocar el actual (parcheo *out-of-place*).

### 5.1 Crear el home

**En nodo1, como root:**

```bash
[root@nodo1 ~]# dbaascli dbhome create --version 19.31.0.0.0
```

- Usa la imagen APR2026 descargada en la Fase 3.
- Puedes fijar el nombre del home añadiendo `--oracleHomeName OraHome1931` (opcional; si no, asigna uno automático).
- Duración típica: 30 – 60 minutos.

### 5.2 Verificar el home en ambos nodos

```bash
[root@nodo1 ~]# dbaascli dbHome getDetails
```

Debe listar el nuevo home con `VERSION=19.31.0.0`. Anota su `HOME_LOC`: es tu **`<HOME_NUEVO>`**.

```text
✍ <HOME_NUEVO>:            
✍ Nombre del home nuevo:   
```

Comprueba que el directorio existe físicamente **en los dos nodos** (dbhome create lo despliega en todo el clúster; si no existiera en nodo2, revisa el log del `dbhome create` antes de continuar):

```bash
[root@nodo1 ~]# ls -d <HOME_NUEVO>
[root@nodo2 ~]# ls -d <HOME_NUEVO>
```

**Parches incluidos en el nuevo home (como oracle):**

```bash
(oracle@nodo1)$ <HOME_NUEVO>/OPatch/opatch lspatches -oh <HOME_NUEVO>
```

Debe verse `Database Release Update : 19.31.0.0.XXXXXX` y el OJVM correspondiente.

---

## Fase 6 — Mover la base de datos al nuevo home (database move)

**Tiempo estimado: 1 – 2 horas** (prereqs 10 – 20 min; move 30 – 60 min; datapatch y recompilación incluidos).
**Impacto:** rolling instancia a instancia — el comando para y arranca la instancia de cada nodo de una en una. Las sesiones conectadas a la instancia que se reinicia se cortan; el servicio global se mantiene por la otra instancia.

### 6.1 Pasar los prerrequisitos del move

**En nodo1, como root** (sustituye `<DB_NAME>` y `<HOME_NUEVO>` por los valores reales):

```bash
[root@nodo1 ~]# dbaascli database move --dbname <DB_NAME> --ohome <HOME_NUEVO> --executePrereqs
```

Debe recorrer los jobs de validación (`validate_database`, `validate_home_existence`, `validate_disk_space`, ...) y terminar con `dbaascli execution completed` sin errores. Si falla algo, corrígelo antes de seguir.

### 6.2 Estado previo de la BBDD

**Como oracle en nodo1**, conecta a la BBDD y anota el estado de los PDBs (para comparar después):

```bash
(oracle@nodo1)$ srvctl status database -d <DB_NAME>
(oracle@nodo1)$ sqlplus / as sysdba
SQL> select name, open_mode from v$pdbs;
SQL> select version_full from v$instance;
SQL> exit
```

Las dos instancias deben estar arriba y los PDBs en el open_mode habitual (normalmente `READ WRITE`).

```text
✍ PDBs y open_mode ANTES del move: 
```

### 6.3 Ejecutar el move

**En nodo1, como root:**

```bash
[root@nodo1 ~]# dbaascli database move --dbname <DB_NAME> --ohome <HOME_NUEVO>
```

Qué hace, en orden:

1. Copia ficheros de configuración al nuevo home (`copy_config_files`).
2. Para la instancia del nodo1, la re-registra apuntando al nuevo home y la arranca (`stop/update/start_database_instance-nodo1`).
3. Repite lo mismo en el nodo2.
4. Ejecuta **datapatch** (aplica los cambios SQL del parche dentro de la BBDD) y **recompila objetos inválidos**. Esta parte puede tardar 15 – 30 minutos y es cuando el comando parece "parado": es normal, espera.
5. Termina con `dbaascli execution completed`.

**No interrumpas el comando.** Si la sesión se corta a mitad, no lo relances a ciegas: revisa primero el log (`/var/opt/oracle/log/<DB_NAME>/database/move/pilot_...`).

```text
✍ Move — hora inicio:   hora fin: 
✍ Log PILOT del move:  
```

### 6.4 Verificar el move

**Como root:**

```bash
[root@nodo1 ~]# dbaascli dbHome getDetails
```

El home 19.31 debe mostrar ahora `DBs installed=<DB_NAME>`; el home viejo debe quedar sin BBDD.

**Como oracle (en ambos nodos):**

```bash
(oracle@nodo1)$ srvctl config database -d <DB_NAME> | grep -i "oracle home"
```

Debe apuntar a `<HOME_NUEVO>`.

```bash
(oracle@nodo1)$ srvctl status database -d <DB_NAME>
(oracle@nodo1)$ <HOME_NUEVO>/OPatch/opatch lspatches -oh <HOME_NUEVO>
```

**Dentro de la BBDD:**

```bash
(oracle@nodo1)$ sqlplus / as sysdba
SQL> select version_full from v$instance;                                   -- debe decir 19.31.0.0.0
SQL> select name, open_mode from v$pdbs;                                    -- igual que antes del move
SQL> select patch_id, status, action, description
     from dba_registry_sqlpatch order by action_time;                       -- última fila: RU 19.31 con status SUCCESS
SQL> select count(*) from dba_objects where status='INVALID' and owner in ('SYS','SYSTEM');  -- idealmente 0
SQL> exit
```

**✔ Hito:** la BBDD ya corre sobre RDBMS 19.31.

---

## Fase 7 — Verificaciones finales y cierre

**Tiempo estimado: 30 – 45 minutos.**

1. **Clúster completo online:**

   ```bash
   (grid@nodo1)$ crsctl check cluster -all
   (grid@nodo1)$ crsctl stat res -t
   (grid@nodo1)$ crsctl query crs activeversion -f     # [NORMAL] y nivel de parche 19.31
   ```

2. **Servicios de la BBDD levantados y PDBs accesibles** (como oracle):

   ```bash
   (oracle@nodo1)$ srvctl status database -d <DB_NAME> -v
   ```

3. **Listener registrando servicios** (probar una conexión de aplicación si es posible).

4. **(Opcional pero recomendable) Repetir exachk** y comparar con el informe de la Fase 2: no deben aparecer FAIL nuevos relacionados con GI/RDBMS.

5. **Avisar al equipo de Linux/Sistemas** de que GI y RDBMS están en 19.31 (≥ 19.24) y pueden planificar su parcheo de sistema operativo.

6. **Cerrar el cambio:** adjunta al CHG las evidencias (salidas de `crsctl query crs activeversion -f`, `opatch lspatches` de grid y RDBMS en ambos nodos, `dba_registry_sqlpatch` y el informe exachk).

7. **Limpieza (días después, no el mismo día):** cuando se confirme que todo funciona (1 – 2 semanas), el home viejo puede eliminarse con `dbaascli dbhome delete --oracleHomeName <nombre_home_viejo>`. No lo hagas el día del cambio: es tu vía de rollback.

```text
✍ Incidencias durante el cambio: 
✍ Hora de cierre del cambio:    ✍ Evidencias adjuntadas al CHG: [ ] Sí
```

---

## Anexo A — Marcha atrás (rollback)

**Solo como último recurso y, salvo urgencia, con el respaldo de Oracle Support.** Referencias oficiales: [documentación de dbaascli para ExaCC](https://docs.oracle.com/en/engineered-systems/exadata-cloud-at-customer/ecccm/ecc-using-dbaascli.html).

### A.1 Volver la BBDD al home antiguo

Gracias al parcheo *out-of-place*, el home viejo sigue intacto. El rollback es otro `move` en sentido contrario:

```bash
[root@nodo1 ~]# dbaascli database move --dbname <DB_NAME> --ohome <HOME_VIEJO>
```

(El proceso vuelve a ejecutar datapatch, esta vez retirando los cambios SQL de la RU.)

### A.2 Rollback del parche de Grid

```bash
[root@nodo1 ~]# dbaascli grid patch --targetVersion <version_anterior> --rollback
```

donde `<version_anterior>` es la versión de GI que había antes (anotada en la Fase 2, p. ej. `19.27.0.0.0`). Es una operación delicada: **abrir SR con Oracle antes de ejecutarla** salvo urgencia justificada.

### A.3 Reanudar una ejecución fallida

Si un `grid patch` o `database move` falla a mitad, dbaascli guarda el estado de la sesión (PILOT). Suele poder reanudarse relanzando **exactamente el mismo comando** con `--resume`:

```bash
[root@nodo1 ~]# dbaascli grid patch --targetVersion 19.31.0.0.0 --nodeList <nodo> --resume
```

Antes de reanudar, revisa siempre el log del fallo y entiende la causa.

---

## Anexo B — Errores y avisos frecuentes

| Mensaje | Qué significa | Qué hacer |
|---|---|---|
| `[WARNING] [DBAAS-70139] A subset of nodes ... has been passed` | Estás parcheando un solo nodo con `--nodeList` | Esperado. Continuar; recuerda parchear el otro nodo. |
| `[FATAL] [DBAAS-70064] Specified cluster nodes '[X]' does not include local node name 'Y'` | Has lanzado el parcheo del nodo X desde el nodo Y | Conéctate al nodo X y lanza el comando allí. |
| `[WARNING] [DBAAS-70212] The target rpm version ... is already installed` | Las tools ya están en la última versión | Informativo. Continuar. |
| `The cluster upgrade state is [ROLLING PATCH]` | Parcheo de GI a medias (un nodo hecho, otro no) | Esperado entre el nodo1 y el nodo2. Si aparece al final, falta un nodo: revisar. |
| Fallo en `validate_disk_space` | Falta espacio en `/u01`, `/u02` o ACFS | Liberar espacio (logs antiguos, backups de homes) y relanzar prereqs. |
| `acquire_lock` falla / lock retenido | Otra operación dbaascli en curso o abortada | No forzar. Comprobar que no hay otra sesión activa antes de reintentar. |
| `dbaascli` se queda "parado" en datapatch | Datapatch en ejecución dentro de la BBDD | Normal (15–30 min). Vigilar el log de PILOT antes de sospechar cuelgue. |

---

## Anexo C — Checklist rápido

```text
FASE 0 — Preparación previa
   [ ] Acceso root a nodo1 y nodo2
   [ ] AHF y CVU descargados
   [ ] ZIPs subidos a /tmp de ambos nodos
   [ ] CHG aprobado (si aplica)

FASE 1 — Actualización de herramientas
   [ ] dbaascli actualizado (misma versión en ambos nodos)
   [ ] AHF actualizado nodo1
   [ ] AHF actualizado nodo2
   [ ] CVU copiado en /opt/oracle.ahf/common/cvu en ambos nodos

FASE 2 — Estado inicial y prechequeos
   [ ] crsctl check cluster -all OK
   [ ] Estado del clúster [NORMAL]
   [ ] Versiones y homes anotados (<HOME_VIEJO>, <DB_NAME>)
   [ ] Espacio en disco validado
   [ ] Informe exachk revisado

FASE 3 — Descarga de imágenes 19.31
   [ ] Imagen BBDD 19.31 descargada (dbimage list muestra APR2026)
   [ ] (Opcional) Imagen grid descargada

FASE 4 — Parcheo del Grid
   [ ] Prereqs grid OK
   [ ] Grid nodo1 parcheado + verificado (ROLLING PATCH esperado)
   [ ] Grid nodo2 parcheado (desde nodo2) + estado [NORMAL]

FASE 5 — Nuevo home RDBMS 19.31
   [ ] dbhome 19.31 creado
   [ ] Home nuevo existe en ambos nodos
   [ ] opatch lspatches del home nuevo OK (<HOME_NUEVO> anotado)

FASE 6 — Database move
   [ ] Prereqs move OK
   [ ] Move ejecutado sin errores
   [ ] srvctl config apunta al home nuevo
   [ ] datapatch SUCCESS en dba_registry_sqlpatch
   [ ] PDBs en el mismo open_mode que antes

FASE 7 — Verificaciones finales y cierre
   [ ] Verificación final + evidencias
   [ ] Aviso a Linux/Sistemas
   [ ] Cierre del CHG
   [ ] (D+7/D+14) Borrar home viejo
```

---

## Referencias

- Documentación oficial dbaascli (ExaCC): <https://docs.oracle.com/en/engineered-systems/exadata-cloud-at-customer/ecccm/ecc-using-dbaascli.html>
- AHF / TFA / exachk: My Oracle Support, Doc ID **2550798.1**
- CVU: <https://www.oracle.com/database/technologies/cvu-downloads.html> (parche MOS **30839369**)
- My Oracle Support: <https://support.oracle.com>
