#!/bin/bash

# Function to initialize the snapshot
init_snapshot() {
    if sudo lvdisplay /dev/rhel/root_snapshot &> /dev/null; then
        echo "Snapshot /dev/rhel/root_snapshot already exists. Aborting init."
        exit 1
    fi

    echo "Creating a 100G snapshot of /dev/rhel/root called root_snapshot..."
    sudo lvcreate --size 100G --snapshot --name root_snapshot /dev/rhel/root
    if [ $? -ne 0 ]; then
        echo "Failed to create LVM snapshot."
        exit 1
    fi

    echo "Creating a Boom snapshot..."
    sudo boom snapshot create --title "Pre RHOSP Deploy" --root-lv /dev/rhel/root_snapshot
    if [ $? -ne 0 ]; then
        echo "Failed to create Boom snapshot."
        exit 1
    fi

    echo "Snapshot initialization complete."
}

# Function to revert to the snapshot
revert_snapshot() {
    if ! sudo lvdisplay /dev/rhel/root_snapshot &> /dev/null; then
        echo "Snapshot /dev/rhel/root_snapshot does not exist. Aborting revert."
        exit 1
    fi

    echo "Reverting to the snapshot..."
    sudo lvconvert --merge /dev/rhel/root_snapshot
    if [ $? -ne 0 ]; then
        echo "Failed to merge LVM snapshot."
        exit 1
    fi

    echo "Cleaning up Boom snapshot entries..."
    local boot_id=$(sudo boom list --format id,title | grep "Pre RHOSP Deploy" | awk '{print $1}')
    if [ -n "$boot_id" ]; then
        sudo boom entry delete --boot-id "$boot_id"
        if [ $? -ne 0 ]; then
            echo "Failed to delete Boom snapshot entry using boom. Attempting manual cleanup."
            # Attempt manual cleanup
            sudo rm -rf /boot/loader/entries/*"$boot_id"*
            if [ $? -ne 0 ]; then
                echo "Manual cleanup of Boom snapshot entry failed."
                exit 1
            fi
        fi
    else
        echo "No Boom snapshot found with the title 'Pre RHOSP Deploy'."
    fi

    if [ "$2" == "restart" ]; then
        echo "Rebooting the system to apply changes..."
        sudo reboot
    else
        echo "Revert completed. No reboot requested."
    fi
}

# Check for the correct number of arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 {revert|init} [restart]"
    exit 1
fi

# Perform the appropriate action based on the argument
case "$1" in
    init)
        init_snapshot
        ;;
    revert)
        revert_snapshot "$@"
        ;;
    *)
        echo "Invalid argument: $1"
        echo "Usage: $0 {revert|init} [restart]"
        exit 1
        ;;
esac

exit 0
