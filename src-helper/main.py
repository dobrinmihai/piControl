import subprocess
import platform
import logging
import re
from flask import Flask, request, jsonify

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO,
                   format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def identify_distro():
    """Identify the Linux distribution."""
    try:
        # Try to get distribution info from /etc/os-release
        with open('/etc/os-release', 'r') as f:
            os_info = f.read()

        if 'fedora' in os_info.lower():
            return 'fedora'
        elif 'arch' in os_info.lower():
            return 'arch'
        elif any(distro in os_info.lower() for distro in ['ubuntu', 'debian', 'mint', 'pop']):
            return 'debian'
        else:
            return 'unknown'
    except Exception as e:
        logger.error(f"Error identifying distribution: {e}")
        return 'unknown'

def install_packages(packages, distro):
    """Install packages based on distribution."""
    results = []

    if not packages:
        return {"success": False, "message": "No packages specified"}

    if distro == 'fedora':
        cmd_base = ['sudo', 'dnf', 'install', '-y']
    elif distro == 'arch':
        cmd_base = ['sudo', 'pacman', '-S', '--noconfirm']
    elif distro == 'debian':
        # Update package lists first
        try:
            subprocess.run(['sudo', 'apt-get', 'update'], check=True)
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to update package lists: {e}")
        cmd_base = ['sudo', 'apt-get', 'install', '-y']
    else:
        return {"success": False, "message": "Unsupported distribution"}

    # Install packages one by one to track success/failure per package
    for package in packages:
        try:
            logger.info(f"Installing package: {package}")
            cmd = cmd_base + [package]
            process = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            results.append({
                "package": package,
                "success": True,
                "message": process.stdout.decode('utf-8')
            })
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to install {package}: {e}")
            results.append({
                "package": package,
                "success": False,
                "message": e.stderr.decode('utf-8')
            })

    return results

def uninstall_packages(packages, distro):
    """Uninstall packages based on distribution."""
    results = []

    if not packages:
        return {"success": False, "message": "No packages specified"}

    if distro == 'fedora':
        cmd_base = ['sudo', 'dnf', 'remove', '-y']
    elif distro == 'arch':
        cmd_base = ['sudo', 'pacman', '-R', '--noconfirm']
    elif distro == 'debian':
        cmd_base = ['sudo', 'apt-get', 'remove', '-y']
    else:
        return {"success": False, "message": "Unsupported distribution"}

    # Uninstall packages one by one to track success/failure per package
    for package in packages:
        try:
            logger.info(f"Uninstalling package: {package}")
            cmd = cmd_base + [package]
            process = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            results.append({
                "package": package,
                "success": True,
                "message": process.stdout.decode('utf-8')
            })
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to uninstall {package}: {e}")
            results.append({
                "package": package,
                "success": False,
                "message": e.stderr.decode('utf-8')
            })

    return results

def search_packages(query, distro):
    """Search for packages based on distribution."""
    if not query:
        return {"success": False, "message": "No search query specified"}

    try:
        if distro == 'fedora':
            cmd = ['dnf', 'search', query]
        elif distro == 'arch':
            cmd = ['pacman', '-Ss', query]
        elif distro == 'debian':
            # Update package lists first
            try:
                subprocess.run(['sudo', 'apt-get', 'update'], check=True)
            except subprocess.CalledProcessError:
                pass
            cmd = ['apt-cache', 'search', query]
        else:
            return {"success": False, "message": "Unsupported distribution"}

        logger.info(f"Searching for packages matching: {query}")
        process = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output = process.stdout.decode('utf-8')

        # Process the output to get a list of packages
        results = []
        if output.strip():
            if distro == 'debian':
                for line in output.splitlines():
                    if line.strip():
                        parts = line.split(' - ', 1)
                        package = parts[0].strip()
                        description = parts[1].strip() if len(parts) > 1 else ""
                        results.append({"name": package, "description": description})
            elif distro == 'fedora':
                # Parse DNF search output
                packages = []
                for line in output.splitlines():
                    if ':' in line and not line.startswith(' '):
                        parts = line.split(':', 1)
                        package = parts[0].strip()
                        description = parts[1].strip() if len(parts) > 1 else ""
                        results.append({"name": package, "description": description})
            elif distro == 'arch':
                # Parse Pacman search output
                current_pkg = None
                for line in output.splitlines():
                    if line.startswith("repo/"):
                        parts = line.split(' ', 1)
                        if len(parts) > 1:
                            full_name = parts[0].strip()
                            current_pkg = full_name.split('/')[-1].split('-')[0]
                            description = parts[1].strip()
                            results.append({"name": current_pkg, "description": description})

        return {"success": True, "results": results}
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to search for packages: {e}")
        return {"success": False, "message": e.stderr.decode('utf-8')}

def list_installed_packages(distro):
    """List installed packages based on distribution."""
    try:
        if distro == 'fedora':
            cmd = ['rpm', '-qa', '--qf', '%{NAME}\t%{VERSION}\n']
        elif distro == 'arch':
            cmd = ['pacman', '-Q']
        elif distro == 'debian':
            cmd = ['dpkg-query', '-W', '-f=${Package}\t${Version}\n']
        else:
            return {"success": False, "message": "Unsupported distribution"}

        logger.info("Listing installed packages")
        process = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output = process.stdout.decode('utf-8')

        # Process the output to get a list of packages
        packages = []
        for line in output.splitlines():
            if line.strip():
                parts = line.split('\t')
                package_name = parts[0].strip()
                version = parts[1].strip() if len(parts) > 1 else ""
                packages.append({"name": package_name, "version": version})

        return {"success": True, "packages": packages}
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to list installed packages: {e}")
        return {"success": False, "message": e.stderr.decode('utf-8')}

def list_systemd_services():
    """List all systemd services."""
    try:
        cmd = ['systemctl', 'list-units', '--type=service', '--all', '--no-pager', '--plain']
        logger.info("Listing systemd services")
        process = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output = process.stdout.decode('utf-8')

        # Process the output to get a list of services
        services = []
        for line in output.splitlines()[1:]:  # Skip header
            if line.strip() and '.service' in line:
                parts = re.split(r'\s+', line.strip(), maxsplit=4)
                if len(parts) >= 3:
                    service_name = parts[0]
                    load_state = parts[1]
                    active_state = parts[2]
                    sub_state = parts[3] if len(parts) > 3 else ""
                    description = parts[4] if len(parts) > 4 else ""

                    services.append({
                        "name": service_name,
                        "load_state": load_state,
                        "active_state": active_state,
                        "sub_state": sub_state,
                        "description": description
                    })

        return {"success": True, "services": services}
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to list systemd services: {e}")
        return {"success": False, "message": e.stderr.decode('utf-8')}

def get_service_status(service_name):
    """Get the status of a systemd service."""
    if not service_name.endswith('.service'):
        service_name = f"{service_name}.service"

    try:
        cmd = ['systemctl', 'status', service_name, '--no-pager']
        logger.info(f"Getting status for service: {service_name}")
        process = subprocess.run(cmd, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output = process.stdout.decode('utf-8')

        # Extract status information
        active_line = re.search(r'Active:\s*(.*)', output)
        active_status = active_line.group(1) if active_line else "Unknown"

        enabled_check = subprocess.run(
            ['systemctl', 'is-enabled', service_name],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False
        )
        enabled_status = enabled_check.stdout.decode('utf-8').strip()

        return {
            "success": True,
            "service": service_name,
            "active_status": active_status,
            "enabled_status": enabled_status,
            "full_status": output
        }
    except Exception as e:
        logger.error(f"Failed to get service status: {e}")
        return {"success": False, "message": str(e)}

def control_service(service_name, action):
    """Control a systemd service (start, stop, enable, disable)."""
    if not service_name.endswith('.service'):
        service_name = f"{service_name}.service"

    valid_actions = ['start', 'stop', 'enable', 'disable', 'restart']
    if action not in valid_actions:
        return {"success": False, "message": f"Invalid action. Valid actions are: {', '.join(valid_actions)}"}

    try:
        cmd = ['sudo', 'systemctl', action, service_name]
        logger.info(f"Running {action} for service: {service_name}")
        process = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        return {
            "success": True,
            "service": service_name,
            "action": action,
            "message": process.stdout.decode('utf-8')
        }
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to {action} service {service_name}: {e}")
        return {
            "success": False,
            "service": service_name,
            "action": action,
            "message": e.stderr.decode('utf-8')
        }

@app.route('/install', methods=['POST'])
def install():
    """API endpoint for package installation."""
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400

    data = request.get_json()

    if 'packages' not in data:
        return jsonify({"error": "No packages specified"}), 400

    packages = data['packages']
    if not isinstance(packages, list):
        return jsonify({"error": "Packages must be a list"}), 400

    distro = identify_distro()
    if distro == 'unknown':
        return jsonify({"error": "Unsupported distribution"}), 400

    results = install_packages(packages, distro)
    return jsonify({
        "distribution": distro,
        "results": results
    })

@app.route('/uninstall', methods=['POST'])
def uninstall():
    """API endpoint for package uninstallation."""
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400

    data = request.get_json()

    if 'packages' not in data:
        return jsonify({"error": "No packages specified"}), 400

    packages = data['packages']
    if not isinstance(packages, list):
        return jsonify({"error": "Packages must be a list"}), 400

    distro = identify_distro()
    if distro == 'unknown':
        return jsonify({"error": "Unsupported distribution"}), 400

    results = uninstall_packages(packages, distro)
    return jsonify({
        "distribution": distro,
        "results": results
    })

@app.route('/search', methods=['GET'])
def search():
    """API endpoint for package search."""
    query = request.args.get('query', '')
    if not query:
        return jsonify({"error": "No search query specified"}), 400

    distro = identify_distro()
    if distro == 'unknown':
        return jsonify({"error": "Unsupported distribution"}), 400

    results = search_packages(query, distro)
    return jsonify({
        "distribution": distro,
        "query": query,
        **results
    })

@app.route('/list_installed', methods=['GET'])
def list_installed():
    """API endpoint to list installed packages."""
    distro = identify_distro()
    if distro == 'unknown':
        return jsonify({"error": "Unsupported distribution"}), 400

    results = list_installed_packages(distro)
    return jsonify({
        "distribution": distro,
        **results
    })

@app.route('/services', methods=['GET'])
def list_services():
    """API endpoint to list all systemd services."""
    results = list_systemd_services()
    return jsonify(results)

@app.route('/service/status', methods=['GET'])
def service_status():
    """API endpoint to get status of a systemd service."""
    service_name = request.args.get('name', '')
    if not service_name:
        return jsonify({"error": "No service name specified"}), 400

    results = get_service_status(service_name)
    return jsonify(results)

@app.route('/service/control', methods=['POST'])
def service_control():
    """API endpoint to control a systemd service."""
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400

    data = request.get_json()

    if 'service' not in data:
        return jsonify({"error": "No service specified"}), 400

    if 'action' not in data:
        return jsonify({"error": "No action specified"}), 400

    service_name = data['service']
    action = data['action']

    results = control_service(service_name, action)
    return jsonify(results)

@app.route('/status', methods=['GET'])
def status():
    """API endpoint to check server status."""
    distro = identify_distro()
    return jsonify({
        "status": "running",
        "distribution": distro
    })

if __name__ == '__main__':
    logger.info(f"Starting PiControl Helper on distribution: {identify_distro()}")
    from waitress import serve
    serve(app, host="0.0.0.0", port=8220)
