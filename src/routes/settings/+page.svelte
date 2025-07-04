<script lang="ts">
    import Icon from '@iconify/svelte';
</script>

<div class="container mx-auto px-4 py-8 min-h-screen font-mono">
    <div class="mb-8">
        <h1 class="text-3xl font-bold tracking-tight">About</h1>
    </div>

    <!-- ESP32 Example Code Card -->
    <div class="mb-8 bg-white border border-neutral-200 rounded-lg shadow-sm p-6">
        <div class="flex items-center gap-4 mb-4">
            <div class="p-3 bg-blue-50 rounded-full">
                <Icon icon="lucide:cpu" class="h-8 w-8 text-blue-600" />
            </div>
            <div>
                <h3 class="text-lg font-semibold">ESP32 Example Code</h3>
                <p class="text-sm text-neutral-600">How your ESP32 should expose sensors and status</p>
            </div>
        </div>
        <div class="mb-4">
            <p class="text-base text-neutral-700 mb-4">
                <strong>Note:</strong> This example uses only <span class="font-semibold">CircuitPython</span>.<br>
                CircuitPython is recommended because it is beginner-friendly, has excellent library support, and allows for rapid prototyping and easy code updates directly on the device.
            </p>
            <div class="mb-4">
                <a href="https://learn.adafruit.com/welcome-to-circuitpython/installing-circuitpython" target="_blank" class="inline-flex items-center text-purple-600 hover:underline text-base">
                    Check CircuitPython installation guide
                </a>
            </div>
            {@html `<pre class='bg-white text-black rounded p-4 overflow-x-auto text-xs border border-neutral-200'><code>import wifi\nimport socketpool\nimport time\nimport adafruit_httpserver\nimport json\n\nSSID = \"wifi_name\"\nPASSWORD = \"password\"\n\nprint(\"Connecting to Wi-Fi...\")\nwifi.radio.connect(SSID, PASSWORD)\nprint(\"Connected! IP:\", wifi.radio.ipv4_address)\n\npool = socketpool.SocketPool(wifi.radio)\nserver = adafruit_httpserver.Server(pool, \"/static\", debug=True)\nserver.start(str(wifi.radio.ipv4_address), port=8321)\n\ndef get_sensor_data():\n    # Replace with your actual sensor reading code\n    # Example: return a list of sensor dicts\n    return [\n        {\"name\": \"Temperature\", \"type\": \"DHT22\", \"value\": 24.5},\n        {\"name\": \"Humidity\", \"type\": \"DHT22\", \"value\": 60}\n    ]\n\n@server.route(\"/status\")\def status_handler(request):\n    return adafruit_httpserver.Response(request, content_type=\"application/json\", body='{"online": true}')\n\n@server.route(\"/sensors\")\def sensors_handler(request):\n    sensors = get_sensor_data()\n    body = json.dumps(sensors)\n    return adafruit_httpserver.Response(request, content_type=\"application/json\", body=body)\n\nwhile True:\n    try:\n        server.poll()\n    except Exception as e:\n        print(\"Server error:\", e)\n    time.sleep(0.1)\n</code></pre>`}
        </div>
        <div class="mb-2">
            <h4 class="text-base font-semibold mb-2">Why this structure?</h4>
            <ul class="list-disc pl-6 text-base text-neutral-700">
                <li>Wi-Fi connection and HTTP server setup allow the PiControl backend to discover and communicate with your ESP32.</li>
                <li>The <span class="">/status</span> endpoint is used for online checks.</li>
                <li>The <span class="">/sensors</span> endpoint should return a JSON array of sensor readings, so the dashboard can display live data.</li>
                <li>Use <span class="">adafruit_httpserver</span> for simple HTTP routing on CircuitPython.</li>
            </ul>
        </div>
        <div class="flex flex-col gap-2 mt-2">
            <a href="https://github.com/dobrinmihai/Esp32-code.py-model/blob/main/code.py" target="_blank" class="inline-flex items-center text-blue-600 hover:underline text-base">
                <Icon icon="mdi:github" class="mr-1" />
                View full code on GitHub
            </a>
            <a href="https://github.com/dobrinmihai/Esp32-code.c" target="_blank" class="inline-flex items-center text-green-700 hover:underline text-base">
                <Icon icon="mdi:github" class="mr-1" />
                See the C version of the code on GitHub
            </a>
        </div>
    </div>

    <!-- Raspberry Pi Helper Install Tutorial Card -->
    <div class="mb-8 bg-white border border-neutral-200 rounded-lg shadow-sm p-6">
        <div class="flex items-center gap-4 mb-4">
            <div class="p-3 bg-green-50 rounded-full">
                <Icon icon="lucide:server" class="h-8 w-8 text-green-600" />
            </div>
            <div>
                <h3 class="text-lg font-semibold">Install Helper on Raspberry Pi</h3>
                <p class="text-sm text-neutral-600">Step-by-step guide with TOTP authentication</p>
            </div>
        </div>
        <ol class="list-decimal pl-6 text-base text-neutral-700 mb-4">
            <li>Clone the repository or copy the <span class="font-mono">src-helper</span> folder to your Raspberry Pi.</li>
            <li>Install Go (if not already): <span class="font-mono">sudo apt update &amp;&amp; sudo apt install golang</span></li>
            <li>Build the helper for your architecture:<br/>
                <span class="block bg-neutral-100 rounded p-2 my-1 font-mono">cd src-helper<br/>make</span>
                This will produce binaries in the <span class="font-mono">build/</span> directory:
                <ul class="list-disc pl-6 mt-1 text-base">
                    <li><span class="font-mono">picontrol-helper-linux-amd64</span> (for x86_64)</li>
                    <li><span class="font-mono">picontrol-helper-linux-arm</span> (for 32-bit ARM)</li>
                    <li><span class="font-mono">picontrol-helper-linux-arm64</span> (for 64-bit ARM)</li>
                </ul>
            </li>
            <li>Run the helper (choose the correct binary for your architecture):<br/>
                <span class="block bg-neutral-100 rounded p-2 my-1 font-mono">./build/picontrol-helper-linux-amd64</span>
                or for ARM:<br/>
                <span class="block bg-neutral-100 rounded p-2 my-1 font-mono">./build/picontrol-helper-linux-arm64</span>
            </li>
            <li><strong>First-time setup:</strong> On first run, the helper will:
                <ul class="list-disc pl-6 mt-1 text-base">
                    <li>Generate a TOTP secret for authentication</li>
                    <li>Display a QR code in the terminal</li>
                    <li>Save configuration to <span class="font-mono">/picontrol-helper/config/</span></li>
                </ul>
            </li>
            <li><strong>Set up your authenticator app:</strong>
                <ul class="list-disc pl-6 mt-1 text-base">
                    <li>Install Google Authenticator, Authy, or any TOTP app on your phone</li>
                    <li>Scan the QR code displayed in the terminal</li>
                    <li>The account will be named <span class="font-mono">PiControl@hostname</span></li>
                </ul>
            </li>
            <li>The helper is now running on port <span class="font-mono">8220</span> and requires TOTP authentication for access.</li>
        </ol>
        <div class="bg-yellow-50 border border-yellow-200 rounded p-3 mb-2">
            <p class="text-base text-yellow-800 font-mono">
                <strong>⚠️ Security Note:</strong> The helper now uses TOTP authentication. You'll need to enter a 6-digit code from your authenticator app when accessing device configuration in the PiControl dashboard.
            </p>
        </div>
        <p class="text-base text-neutral-500 mt-2 font-mono">For more details, see the <span class="font-mono">AUTH_README.md</span> in <span class="font-mono">src-helper</span>.</p>
    </div>

    <!-- System Information -->
    <div class="mt-0 bg-white border border-neutral-200 rounded-lg shadow-sm p-6">
        <div class="flex items-center gap-4 mb-4">
            <div class="p-3 bg-orange-50 rounded-full">
                <Icon icon="lucide:info" class="h-8 w-8 text-orange-600" />
            </div>
            <div>
                <h3 class="text-lg font-semibold">System Information</h3>
                <p class="text-sm text-neutral-600">About PiControl IoT</p>
            </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div class="text-center">
                <Icon icon="lucide:code" class="h-8 w-8 mx-auto text-blue-500 mb-2" />
                <h4 class="text-sm font-semibold">Framework</h4>
                <p class="text-xs text-neutral-600">SvelteKit + TypeScript</p>
            </div>
            <div class="text-center">
                <Icon icon="lucide:database" class="h-8 w-8 mx-auto text-green-500 mb-2" />
                <h4 class="text-sm font-semibold">Database</h4>
                <p class="text-xs text-neutral-600">PocketBase</p>
            </div>
            <div class="text-center">
                <Icon icon="lucide:terminal" class="h-8 w-8 mx-auto text-purple-500 mb-2" />
                <h4 class="text-sm font-semibold">Backend</h4>
                <p class="text-xs text-neutral-600">Go + Fiber</p>
            </div>
            <div class="text-center">
                <Icon icon="lucide:cpu" class="h-8 w-8 mx-auto text-red-500 mb-2" />
                <h4 class="text-sm font-semibold">Target</h4>
                <p class="text-xs text-neutral-600">Raspberry Pi + ESP32</p>
            </div>
        </div>
        <div class="mt-6 pt-4 border-t border-neutral-200 text-center">
            <p class="text-base text-neutral-600">
                PiControl IoT - A comprehensive solution for managing and monitoring IoT devices
            </p>
            <p class="text-base text-neutral-600 mt-2">
                This project lets you easily connect, monitor, and control ESP32 and Raspberry Pi devices from a modern web dashboard. It provides device status, sensor data, and simple setup guides for both platforms.
            </p>
        </div>
    </div>
</div>
