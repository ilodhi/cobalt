import { base } from "$app/paths";

export function appPath(path: string): string {
    if (!path.startsWith("/")) {
        path = `/${path}`;
    }

    return `${base}${path}`;
}

export function stripAppBase(pathname: string): string {
    if (base && pathname.startsWith(base)) {
        return pathname.slice(base.length) || "/";
    }

    return pathname;
}
