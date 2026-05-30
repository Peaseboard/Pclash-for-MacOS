#!/bin/bash
# PClash Linux System Proxy Helper
# Supports GNOME (gsettings), KDE (kwriteconfig5), and generic (environment)
# Usage: ./linux_proxy_helper.sh <enable|disable|status|autostart> [port]

set -e

DESKTOP=""
PROXY_HOST="127.0.0.1"
PROXY_PORT="${2:-7890}"

# Detect desktop environment
detect_desktop() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        case "$XDG_CURRENT_DESKTOP" in
            *GNOME*|*Unity*|*Budgie*)
                DESKTOP="gnome"
                ;;
            *KDE*|*Plasma*)
                DESKTOP="kde"
                ;;
            *XFCE*)
                DESKTOP="xfce"
                ;;
            *)
                # Fallback: try gsettings first
                if command -v gsettings &>/dev/null; then
                    DESKTOP="gnome"
                elif command -v kwriteconfig5 &>/dev/null; then
                    DESKTOP="kde"
                else
                    DESKTOP="generic"
                fi
                ;;
        esac
    else
        DESKTOP="generic"
    fi
}

# Enable proxy
enable_proxy() {
    local port=$1
    
    case "$DESKTOP" in
        gnome)
            # GNOME uses gsettings
            gsettings set org.gnome.system.proxy mode 'manual'
            gsettings set org.gnome.system.proxy.http host "$PROXY_HOST"
            gsettings set org.gnome.system.proxy.http port "$port"
            gsettings set org.gnome.system.proxy.https host "$PROXY_HOST"
            gsettings set org.gnome.system.proxy.https port "$port"
            gsettings set org.gnome.system.proxy.socks host "$PROXY_HOST"
            gsettings set org.gnome.system.proxy.socks port "$port"
            # Bypass local addresses
            gsettings set org.gnome.system.proxy ignore-hosts "['localhost', '127.0.0.0/8', '::1', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']"
            ;;
        kde)
            # KDE uses kwriteconfig5
            kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key ProxyType 1
            kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key httpProxy "http://$PROXY_HOST:$port"
            kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key httpsProxy "http://$PROXY_HOST:$port"
            kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key socksProxy "socks://$PROXY_HOST:$port"
            # Notify KDE of change
            qdbus org.kde.KGlobalSettings /KGlobalSettings notifyChange 0 0 &>/dev/null || true
            ;;
        xfce)
            # XFCE uses gsettings via xfce4-settings
            gsettings set org.gnome.system.proxy mode 'manual' 2>/dev/null || true
            gsettings set org.gnome.system.proxy.http host "$PROXY_HOST" 2>/dev/null || true
            gsettings set org.gnome.system.proxy.http port "$port" 2>/dev/null || true
            ;;
        generic)
            # Export to environment (only affects current session)
            export http_proxy="http://$PROXY_HOST:$port"
            export https_proxy="http://$PROXY_HOST:$port"
            export no_proxy="localhost,127.0.0.0/8,::1"
            echo "warning: generic desktop, proxy only applies to current session"
            ;;
    esac
    
    echo "enabled"
}

# Disable proxy
disable_proxy() {
    case "$DESKTOP" in
        gnome)
            gsettings set org.gnome.system.proxy mode 'none'
            ;;
        kde)
            kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key ProxyType 0
            qdbus org.kde.KGlobalSettings /KGlobalSettings notifyChange 0 0 &>/dev/null || true
            ;;
        xfce)
            gsettings set org.gnome.system.proxy mode 'none' 2>/dev/null || true
            ;;
        generic)
            unset http_proxy https_proxy
            echo "warning: generic desktop, environment variables cleared for current session"
            ;;
    esac
    
    echo "disabled"
}

# Get proxy status
get_status() {
    local mode="none"
    local port=0
    
    case "$DESKTOP" in
        gnome)
            mode=$(gsettings get org.gnome.system.proxy mode 2>/dev/null | tr -d "'") || mode="none"
            port=$(gsettings get org.gnome.system.proxy.http port 2>/dev/null) || port=0
            ;;
        kde)
            local proxy_type
            proxy_type=$(kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key ProxyType --get 2>/dev/null) || proxy_type=0
            if [ "$proxy_type" = "1" ]; then
                mode="manual"
            else
                mode="none"
            fi
            ;;
        xfce)
            mode=$(gsettings get org.gnome.system.proxy mode 2>/dev/null | tr -d "'") || mode="none"
            ;;
        generic)
            if [ -n "$http_proxy" ]; then
                mode="manual"
            else
                mode="none"
            fi
            ;;
    esac
    
    echo "{\"mode\": \"$mode\", \"port\": $port, \"desktop\": \"$DESKTOP\"}"
}

# Set up auto-start
setup_autostart() {
    local enabled=$1
    local app_path="${3:-pclash}"
    
    if [ "$enabled" = "true" ]; then
        # Create systemd user service
        mkdir -p ~/.config/systemd/user
        
        cat > ~/.config/systemd/user/pclash.service << EOF
[Unit]
Description=PClash Proxy Client
After=network-online.target

[Service]
Type=simple
ExecStart=$app_path
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
        
        systemctl --user daemon-reload
        systemctl --user enable pclash.service
        echo "autostart enabled (systemd)"
    else
        systemctl --user disable pclash.service 2>/dev/null || true
        rm -f ~/.config/systemd/user/pclash.service
        systemctl --user daemon-reload
        echo "autostart disabled"
    fi
}

# Main
ACTION="${1:-status}"
detect_desktop

case "$ACTION" in
    enable)
        enable_proxy "$PROXY_PORT"
        ;;
    disable)
        disable_proxy
        ;;
    status)
        get_status
        ;;
    autostart)
        setup_autostart "${2:-true}" "${3:-pclash}"
        ;;
    *)
        echo "Usage: $0 {enable|disable|status|autostart} [port] [app_path]"
        exit 1
        ;;
esac
