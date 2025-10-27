# Ansible: Generación de migraciones DB→DB

Este playbook genera una migración Flyway por diferencia entre la BD de desarrollo (origen) y la BD en los contenedores (destino), usando Liquibase a través de Maven en un contenedor Docker.

## Requisitos
- Docker disponible en el host que ejecuta el playbook.
- La red de Docker de tus servicios si necesitas resolver `patroni-master` (opcional, p.ej. `eda-backend-plus_default`).

## Variables
Copia `ansible/vars/example.yml` a `ansible/vars/dev.yml` y ajusta:

- `src_*`: conexión de la BD de desarrollo.
- `dst_*`: conexión de la BD de contenedores.
- `schema`: normalmente `pos`.
- `docker_network`: si necesitas que el contenedor Maven resuelva los hosts de tu compose.

## Uso
### Con Ansible instalado
```
ansible-playbook ansible/playbooks/generate_db_migration.yml -e @ansible/vars/dev.yml
```

### Sin Ansible instalado (vía wrapper PowerShell)
```
powershell -File scripts/run-ansible.ps1 -VarsFile "ansible/vars/dev.yml"
```

El playbook creará un archivo en `src/main/resources/db/migration/V<N>__<slug>.sql` con cabecera estándar y `SET LOCAL search_path TO <schema>;`.

## Notas
- El SQL generado puede incluir objetos en otros esquemas. Revísalo y cualifícalo si es necesario.
- Flyway ejecuta cada migración en transacción. No añadas `BEGIN/COMMIT` al SQL.
- Si no hay diferencias, el playbook fallará antes de crear la migración.