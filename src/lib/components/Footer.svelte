<script lang="ts">
    import Icon from '@iconify/svelte';
    import { slide } from 'svelte/transition';
    import { onMount } from 'svelte';
    
    let isConsoleOpen = false;
    let term:any;
    let socket:any;
    let sshUsername = "root"; // Changed default from "raymond" to "root"
    let sshHost = "127.0.0.1"; // Added variable for IP address
    let isConnected = false;
    let terminalElement:HTMLElement | null = null;
    let isPasswordPromptVisible = false;
    let passwordInput = "";

    async function connectWithPassword() {
        if (!passwordInput) return;
        
        try {
            // Dynamically import Terminal only in the browser
            const { Terminal } = await import("xterm");
            const { FitAddon } = await import("xterm-addon-fit");
            
            // Add xterm.css
            if (!document.getElementById('xterm-css')) {
                const link = document.createElement('link');
                link.id = 'xterm-css';
                link.rel = 'stylesheet';
                link.href = 'https://cdn.jsdelivr.net/npm/xterm@5.1.0/css/xterm.css';
                document.head.appendChild(link);
            }

            // Initialize terminal
            term = new Terminal({
                cursorBlink: true,
                theme: {
                    background: '#000',
                    foreground: '#3DF547'
                }
            });
            
            const fitAddon = new FitAddon();
            term.loadAddon(fitAddon);
            
            if (terminalElement) {
                term.open(terminalElement);
                fitAddon.fit();
            } else {
                console.error("Terminal element not found");
                return;
            }

            // Connect to Socket.IO server
            const { io } = await import("socket.io-client");
            socket = io("http://localhost:3000");

            socket.on("connect", () => {
                console.log("Connected to server");
                socket.emit("start_ssh", {
                    hostname: sshHost, // Use variable instead of hardcoded value
                    username: sshUsername,
                    password: passwordInput,
                });

                // Clear the temporary password from memory
                passwordInput = "";
                isPasswordPromptVisible = false;
                isConnected = true;
            });

            socket.on("ssh_data", (data:any) => {
                term.write(data);
            });

            socket.on("disconnect", () => {
                isConnected = false;
                term.write("\r\n\x1b[31mDisconnected from server\x1b[0m\r\n");
            });

            term.onData((data:any) => {
                if (isConnected) {
                    socket.emit("input", data);
                }
            });
            
            // Handle terminal resize
            window.addEventListener('resize', () => {
                if (fitAddon) fitAddon.fit();
            });
        } catch (error) {
            console.error("Failed to initialize terminal:", error);
            alert("Failed to initialize terminal. See console for details.");
            isPasswordPromptVisible = false;
        }
    }

    function initTerminal() {
        if (isConnected) return;
        isPasswordPromptVisible = true;
    }

    function handleConsoleToggle() {
        isConsoleOpen = !isConsoleOpen;
        if (isConsoleOpen && !isConnected) {
            // Initialize terminal on next tick after the DOM is updated
            setTimeout(initTerminal, 0);
        }
    }

    function cancelPasswordPrompt() {
        isPasswordPromptVisible = false;
        passwordInput = "";
        if (!isConnected) {
            isConsoleOpen = false;
        }
    }

    onMount(() => {
        return () => {
            // Clean up on component unmount
            if (socket) {
                socket.disconnect();
            }
        };
    });
</script>

<footer class="border-t border-neutral-800 bg-black">
  <div class="container mx-auto px-4">
    <div class="flex items-center justify-between h-12">
      <div class="flex items-center space-x-3">
        <div class="flex items-center space-x-1">
          <Icon icon="lucide:circle" class="h-2 w-2 text-green-500" style="fill: rgb(34, 197, 94);" />
          <span class="text-xs font-mono text-neutral-400">SYSTEM ONLINE</span>
        </div>
        <span class="text-xs font-mono text-neutral-400">|</span>
        <span class="text-xs font-mono text-neutral-400">v1.0.2</span>
      </div>

      <button
        class="h-8 px-3 py-1 font-mono text-white text-xs border border-neutral-800 bg-transparent hover:bg-neutral-900 inline-flex items-center"
        on:click={handleConsoleToggle}
      >
        <Icon icon="lucide:terminal" class="h-3 w-3 mr-2" />
        CONSOLE
        {#if isConsoleOpen}
          <Icon icon="lucide:chevron-down" class="h-3 w-3 ml-2" />
        {:else}
          <Icon icon="lucide:chevron-up" class="h-3 w-3 ml-2" />
        {/if}
      </button>
    </div>
  </div>

  {#if isConsoleOpen}
    <div 
      class="border-t border-neutral-800 bg-neutral-900"
      transition:slide={{ duration: 300 }}
    >
      <div class="container mx-auto px-4 py-3 h-64">
        <div class="font-mono text-xs bg-black p-3 h-full overflow-hidden" bind:this={terminalElement}>
          <!-- Terminal will be mounted here -->
        </div>
      </div>
    </div>
  {/if}
</footer>

{#if isPasswordPromptVisible}
<div class="fixed inset-0 bg-black bg-opacity-70 flex items-center justify-center z-50">
  <div class="bg-neutral-900 border border-neutral-800 p-4 rounded shadow-lg w-80">
    <h3 class="text-white font-mono text-sm mb-4">SSH Authentication</h3>
    

    <div class="mb-4">
      <label for="sshUsername" class="block text-neutral-400 text-xs font-mono mb-1">Username</label>
      <input 
        type="text" 
        id="sshUsername" 
        bind:value={sshUsername} 
        class="w-full bg-black border border-neutral-800 text-white px-2 py-1 text-sm font-mono focus:outline-none focus:border-neutral-600"
      />
    </div>  

    <div class="mb-4">
      <label for="sshHost" class="block text-neutral-400 text-xs font-mono mb-1">Host IP Address</label>
      <input 
        type="text" 
        id="sshHost" 
        bind:value={sshHost} 
        class="w-full bg-black border border-neutral-800 text-white px-2 py-1 text-sm font-mono focus:outline-none focus:border-neutral-600"
      />
    </div>

    
    <div class="mb-4">
      <label for="sshPassword" class="block text-neutral-400 text-xs font-mono mb-1">Password for {sshUsername}@{sshHost}</label>
      <input 
        type="password" 
        id="sshPassword" 
        bind:value={passwordInput} 
        class="w-full bg-black border border-neutral-800 text-white px-2 py-1 text-sm font-mono focus:outline-none focus:border-neutral-600"
        autocomplete="current-password"
      />
    </div>
    
    <div class="flex justify-end space-x-2">
      <button 
        class="px-3 py-1 text-xs font-mono text-neutral-300 hover:text-white"
        on:click={cancelPasswordPrompt}
      >
        Cancel
      </button>
      <button 
        class="px-3 py-1 text-xs font-mono bg-neutral-800 text-white hover:bg-neutral-700"
        on:click={connectWithPassword}
      >
        Connect
      </button>
    </div>
  </div>
</div>
{/if}