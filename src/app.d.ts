// See https://svelte.dev/docs/kit/types#app.d.ts

import type { BaseAuthStore } from "pocketbase";
import type PocketBase from "pocketbase";

// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			pb: PocketBase;
			user: BaseAuthStore["model"];
		}
		// interface Locals {}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
