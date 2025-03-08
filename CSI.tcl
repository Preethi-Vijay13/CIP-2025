# Create a simulator instance
set ns [new Simulator]

# Create a NAM trace file
set namfile [open wsn_authentication.nam w]
$ns namtrace-all $namfile

# Define the number of nodes
set num_nodes 20
set cluster_heads {}
array set node_csi {}  ;# Initialize node_csi as an associative array
array set node_pos {}  ;# Store node positions

# Set up nodes and assign random CSI values
set total_csi 0
for {set i 0} {$i < $num_nodes} {incr i} {
    set node($i) [$ns node]
    set csi [expr 0.8 + rand() * 0.4]  ;# Random CSI between 0.8 and 1.2
    set node_csi($i) $csi
    set total_csi [expr $total_csi + $csi]
    
    # Assign random positions within 300x300 area for better visibility
    set x [expr rand() * 300]
    set y [expr rand() * 300]
    set node_pos($i) "$x $y"
    
    $node($i) set X_ $x
    $node($i) set Y_ $y
    $node($i) set Z_ 0.0
}

# Compute dynamic authentication threshold
set avg_csi [expr $total_csi / $num_nodes]
set AUTHENTICATION_THRESHOLD [expr 0.3 * $avg_csi]  ;# Dynamic threshold

# Set transmission range
set TRANSMISSION_RANGE 100  ;# Nodes must be within 100 units to communicate

# Select 5 random nodes as cluster heads
for {set i 0} {$i < 5} {incr i} {
    set ch [expr int(rand() * $num_nodes)]
    if {[lsearch -exact $cluster_heads $ch] == -1} {
        lappend cluster_heads $ch
        $node($ch) color "Blue"  ;# Mark cluster heads as blue
    } else {
        incr i -1
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

# Process each node and check authentication
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
        
        set node_csi_val $node_csi($i)
        set ch_csi_val $node_csi($nearest_ch)
        set diff [expr abs($node_csi_val - $ch_csi_val)]
        
        if {$min_dist < $TRANSMISSION_RANGE && $diff <= $AUTHENTICATION_THRESHOLD} {
            puts "Node $i -> Cluster Head $nearest_ch: ✅ Accepted"
            $node($i) color "green"  ;# Mark authenticated nodes as green
            $ns duplex-link $node($i) $node($nearest_ch) 1Mb 10ms DropTail  ;# Create a link
        } else {
            puts "Node $i -> Cluster Head $nearest_ch: ❌ Denied (Possible Eavesdropper)"
            $node($i) color "red"  ;# Mark denied nodes as red
            $ns at 0.5 "$node($i) label X"  ;# Put an X mark
           
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
$ns at 5.0 "finish"

# Run simulation
$ns run
