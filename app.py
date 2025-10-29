from flask import Flask, request, jsonify
import subprocess

app = Flask(__name__)

@app.route('/api/migrate', methods=['POST'])
def migrate():
    data = request.get_json()

    command = [
        'python',
        './scripts/run_migration.py',
        '--description', data.get('description', 'Migration from API'),
        '--src-host', data.get('src_host', '127.0.0.1'),
        '--src-port', str(data.get('src_port', 5432)),
        '--src-db', data.get('src_db', 'sasdatqbox'),
        '--src-user', data.get('src_user', 'sas_user'),
        '--src-password', data.get('src_password', ''),
        '--dst-host', data.get('dst_host', 'patroni-master'),
        '--dst-port', str(data.get('dst_port', 5432)),
        '--dst-db', data.get('dst_db', 'sasdatqbox'),
        '--dst-user', data.get('dst_user', 'sas_user'),
        '--dst-password', data.get('dst_password', ''),
        '--schema', data.get('schema', 'pos'),
        '--output-dir', data.get('output_dir', 'src/main/resources/db/migration'),
    ]

    if data.get('no_docker'):
        command.append('--no-docker')
    if data.get('docker_network'):
        command.extend(['--docker-network', data.get('docker_network')])
    if data.get('mode'):
        command.extend(['--mode', data.get('mode')])
    if data.get('test'):
        command.append('--test')

    process = subprocess.run(command, capture_output=True, text=True)

    if process.returncode == 0:
        return jsonify({'status': 'success', 'output': process.stdout})
    else:
        return jsonify({'status': 'error', 'output': process.stderr}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5001)