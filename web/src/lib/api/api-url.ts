import env from "$lib/env";
import { get } from "svelte/store";
import settings from "$lib/state/settings";
import { getRuntimeApi } from "$lib/api/api-config";

export const currentApiURL = () => {
    const processingSettings = get(settings).processing;
    const customInstanceURL = processingSettings.customInstanceURL;

    if (processingSettings.enableCustomInstances && customInstanceURL.length > 0) {
        return new URL(customInstanceURL).origin;
    }

    const runtimeApi = getRuntimeApi();
    if (runtimeApi) {
        return new URL(runtimeApi).origin;
    }

    return new URL(env.DEFAULT_API!).origin;
}
