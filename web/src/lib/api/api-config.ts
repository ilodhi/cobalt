let loaded = false;
let runtimeApi: string | undefined;

export async function loadApiConfig() {
    if (loaded) {
        return;
    }

    loaded = true;

    try {
        const response = await fetch(`${import.meta.env.BASE_URL}api-config.json`, {
            cache: "no-store",
        });

        if (!response.ok) {
            return;
        }

        const data = await response.json() as { defaultApi?: string };

        if (data.defaultApi) {
            runtimeApi = data.defaultApi;
        }
    } catch {
        // optional runtime override for static hosts (e.g. github pages)
    }
}

export function getRuntimeApi() {
    return runtimeApi;
}
