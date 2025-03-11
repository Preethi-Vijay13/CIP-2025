# Create a simulator instance
set ns [new Simulator]

# Create a NAM trace file
set namfile [open wsn_authentication.nam w]
$ns namtrace-all $namfile

# Load the SHA-256 package for authentication
package require Tcl 8.5
package require sha256

# Define the number of nodes
set num_nodes 20
set cluster_heads {}
array set node_csi {}  ;# Initialize node_csi as an associative array
array set node_pos {}  ;# Store node positions

# Set transmission range
set TRANSMISSION_RANGE 100  ;# Nodes must be within 100 units to communicate
set min_distance 10  ;# Minimum required distance between nodes

# Function to calculate distance between two points
proc distance {x1 y1 x2 y2} {
    return [expr sqrt(pow(($x1 - $x2), 2) + pow(($y1 - $y2), 2))]
}

# Set up nodes with non-overlapping positions
set total_csi 0
for {set i 0} {$i < $num_nodes} {incr i} {
    set valid 0
    while {!$valid} {
        set x [expr rand() * 300]
        set y [expr rand() * 300]
        set valid 1

        # Check distance with all previously placed nodes
        foreach prev [array names node_pos] {
            set prev_x [lindex $node_pos($prev) 0]
            set prev_y [lindex $node_pos($prev) 1]
            if {[distance $x $y $prev_x $prev_y] < $min_distance} {
                set valid 0
                break
            }
        }
    }

    # Assign position if valid
    set node_pos($i) "$x $y"
    set node($i) [$ns node]
    $node($i) set X_ $x
    $node($i) set Y_ $y
    $node($i) set Z_ 0.0

    # Assign CSI values
    set csi [expr 0.5 + rand() * 1.0]  ;# Random CSI between 0.5 and 1.5
    set node_csi($i) $csi
    set total_csi [expr $total_csi + $csi]
}

# Compute dynamic authentication threshold
set avg_csi [expr $total_csi / $num_nodes]
set AUTHENTICATION_THRESHOLD [expr 0.7 * $avg_csi]  ;# Dynamic threshold

# Select 3 random nodes as cluster heads
for {set i 0} {$i < 3} {incr i} {
    set ch [expr int(rand() * $num_nodes)]
    if {[lsearch -exact $cluster_heads $ch] == -1} {
        lappend cluster_heads $ch
        $node($ch) color "Blue"  ;# Mark cluster heads as blue
    } else {
        incr i -1  ;# Retry if the selected node is already a cluster head
    }
}

# Function to calculate Euclidean distance between nodes
proc shortest_path {src dst} {
    global node_pos
    set src_pos $node_pos($src)
    set dst_pos $node_pos($dst)
    
    set src_x [lindex $src_pos 0]
    set src_y [lindex $src_pos 1]
    set dst_x [lindex $dst_pos 0]
    set dst_y [lindex $dst_pos 1]
    
    return [expr sqrt(pow(($src_x - $dst_x), 2) + pow(($src_y - $dst_y), 2))]
}

# Secure Key-Based Encryption and Decryption Functions
set SECRET_KEY 12345  ;# Shared secret key for encryption/decryption

proc encrypt_csi {csi key} {
    set xor_csi [expr int($csi * 1000) ^ $key]  ;# Convert to int, XOR with key
    return $xor_csi
}

proc decrypt_csi {encrypted_csi key} {
    set decrypted_csi [expr $encrypted_csi ^ $key]
    return [expr $decrypted_csi / 1000.0]  ;# Convert back to float
}

# Hash function to generate node authentication token
proc generate_hash {node_id csi key} {
    return [sha2::sha256 -hex "$node_id-$csi-$key"]
}

# Process each node and check authentication with enhanced security
for {set i 0} {$i < $num_nodes} {incr i} {
    if {[lsearch -exact $cluster_heads $i] == -1} {
        set min_dist 10000
        set nearest_ch -1

        foreach ch $cluster_heads {
            set dist [shortest_path $i $ch]
            if {$dist < $min_dist} {
                set min_dist $dist
                set nearest_ch $ch
            }
        }

        # Encrypt CSI before transmission
        set encrypted_csi [encrypt_csi $node_csi($i) $SECRET_KEY]

        # Generate node authentication hash
        set auth_token [generate_hash $i $encrypted_csi $SECRET_KEY]

        # Decrypt CSI at the CH
        set decrypted_csi [decrypt_csi $encrypted_csi $SECRET_KEY]

        # Verify CSI and Authentication
        set ch_csi_val $node_csi($nearest_ch)
        set diff [expr abs($decrypted_csi - $ch_csi_val)]
        set expected_token [generate_hash $i $encrypted_csi $SECRET_KEY]

        if {$min_dist < $TRANSMISSION_RANGE && $diff <= $AUTHENTICATION_THRESHOLD && $auth_token eq $expected_token} {
            puts "Node $i -> Cluster Head $nearest_ch: Accepted (Secure Auth)"
            $node($i) color "Orange"
            $ns duplex-link $node($i) $node($nearest_ch) 1Mb 10ms DropTail
        } else {
            puts "Node $i -> Cluster Head $nearest_ch: Denied (Possible Eavesdropper)"
            $node($i) color "Red"
            $ns at 0.5 "$node($i) label X"
        }
    }
}

# Compute routes before starting the simulation
$ns rtproto DV

# Procedure to end the simulation
proc finish {} {
    global ns namfile
    $ns flush-trace
    close $namfile
    exec nam wsn_authentication.nam &
    exit 0
}

# Schedule the finish procedure
$ns at 3.0 "finish"

# Run simulation
$ns run
