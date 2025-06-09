<script lang="ts">
  import { page } from '$app/stores';
  import { user, logout } from '$lib/auth';
  import Icon from "@iconify/svelte";
  import Logo from "$lib/components/Logo.svelte";
  
  const navItems = [
    { name: "Overview", path: "/", icon: "tabler:layout-dashboard" },
    { name: "Devices", path: "/devices", icon: "tabler:server-2" },
    { name: "Settings", path: "/settings", icon: "tabler:settings" },
  ];
  
  async function handleLogout() {
    await logout();
  }
</script>

<header class="border-b border-zinc-800 bg-neutral-900 text-white">
  <div class="container mx-auto px-4 py-3">
    <nav class="flex items-center justify-between">
      <a href="/" class="flex items-center">
        <Logo />
      </a>

      <div class="flex items-center space-x-4">
        <div class="flex space-x-1">
          {#each navItems as item}
            <a
              href={item.path}
              class="px-3 py-2 font-mono text-sm uppercase tracking-wider flex items-center {$page.url.pathname === item.path 
                ? 'bg-white text-black' 
                : 'text-neutral-400 hover:text-white hover:bg-neutral-800'}"
            >
              {item.name}
                <Icon icon={item.icon} class="ml-1" />
            </a>
          {/each}
        </div>
        
        {#if $user}
          <div class="flex items-center space-x-3 ml-4 pl-4 border-l border-neutral-600">
            <span class="text-sm text-neutral-300">
              {$user.email}
            </span>
            <button
              on:click={handleLogout}
              class="px-3 py-1 text-sm text-neutral-400 hover:text-white hover:bg-neutral-800 rounded flex items-center"
            >
              <Icon icon="tabler:logout" class="mr-1" />
              Logout
            </button>
          </div>
        {/if}
      </div>
    </nav>
  </div>
</header>