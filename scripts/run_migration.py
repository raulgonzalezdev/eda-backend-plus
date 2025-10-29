import subprocess
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate DB migration.')
    parser.add_argument('--description', required=True, help='Description of the migration')
    parser.add_argument('--src-host', default='127.0.0.1', help='Source host')
    parser.add_argument('--src-port', type=int, default=5432, help='Source port')
    parser.add_argument('--src-db', default='sasdatqbox', help='Source database')
    parser.add_argument('--src-user', default='sas_user', help='Source user')
    parser.add_argument('--src-password', default='', help='Source password')
    parser.add_argument('--dst-host', default='patroni-master', help='Destination host')
    parser.add_argument('--dst-port', type=int, default=5432, help='Destination port')
    parser.add_argument('--dst-db', default='sasdatqbox', help='Destination database')
    parser.add_argument('--dst-user', default='sas_user', help='Destination user')
    parser.add_argument('--dst-password', default='', help='Destination password')
    parser.add_argument('--schema', default='pos', help='Schema name')
    parser.add_argument('--output-dir', default='src/main/resources/db/migration', help='Output directory')
    parser.add_argument('--no-docker', action='store_true', help='Do not use Docker')
    parser.add_argument('--docker-network', default='', help='Docker network')
    parser.add_argument('--mode', choices=['liquibase', 'pgdump'], default='pgdump', help='Migration mode')
    parser.add_argument('--test', action='store_true', help='Test mode')

    args = parser.parse_args()

    powershell_script = './generate-migration-db2db.ps1'

    command = [
        'powershell',
        '-File',
        powershell_script,
        '-Description', args.description,
        '-SrcHost', args.src_host,
        '-SrcPort', str(args.src_port),
        '-SrcDb', args.src_db,
        '-SrcUser', args.src_user,
        '-SrcPassword', args.src_password,
        '-DstHost', args.dst_host,
        '-DstPort', str(args.dst_port),
        '-DstDb', args.dst_db,
        '-DstUser', args.dst_user,
        '-DstPassword', args.dst_password,
        '-Schema', args.schema,
        '-OutputDir', args.output_dir,
    ]

    if args.no_docker:
        command.append('-NoDocker')
    if args.docker_network:
        command.extend(['-DockerNetwork', args.docker_network])
    if args.mode:
        command.extend(['-Mode', args.mode])
    if args.test:
        command.append('-Test')

    process = subprocess.run(command, capture_output=True, text=True)

    if process.returncode == 0:
        print(process.stdout)
    else:
        print(f"Error: {process.stderr}")