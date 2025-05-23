import type { PageServerLoad } from './$types';

export async function load({ fetch }:any) {
    try {
      const response = await fetch('/data.json');
      const devices = await response.json();
      return { devices };
    } catch (error) {
      console.error('Error fetching devices:', error);
      return { devices: [] };
    }
  }