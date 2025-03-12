# Initialize NS2 Simulator
set ns [new Simulator]

# Create Trace and NAM files
set tracefile [open wired.tr w]
$ns trace-all $tracefile

# Open a file to store SINR values
set sinr_tracefile [open sinr_results.tr w]

set namfile [open wired.nam w]
$ns namtrace-all $namfile

# Define Node Colors
$ns color 1 Black    ;# Normal Nodes
$ns color 2 Green    ;# Cluster Heads
$ns color 3 Blue     ;# Base Station
$ns color 4 Yellow   ;# Eavesdropper
$ns color 5 Purple   ;# Jamming Signal

# Create 10 Normal Nodes
set nodes {}
for {set i 0} {$i < 10} {incr i} {
    set node($i) [$ns node]
    $node($i) color Black
    lappend nodes $node($i)
}

# Define Base Station (BS)
set bs [$ns node]
$bs color Blue

# Select Random Cluster Heads (CHs)
set ch1 $node([expr {int(rand() * 10)}])
set ch2 $node([expr {int(rand() * 10)}])
$ch1 color Green
$ch2 color Green

# Define Eavesdroppers (Only linked to CHs)
set eav1 [$ns node]
set eav2 [$ns node]
$eav1 color Yellow
$eav2 color Yellow

# Create Links (Cluster Heads → Base Station)
$ns duplex-link $ch1 $bs 2Mb 10ms DropTail
$ns duplex-link $ch2 $bs 2Mb 10ms DropTail

# Assign Nodes to Cluster Heads and Establish Links
foreach n $nodes {
    if {$n != $ch1 && $n != $ch2} {
        set rand_ch [expr {int(rand() * 2)}]
        if {$rand_ch == 0} {
            set cluster($n) $ch1
        } else {
            set cluster($n) $ch2
        }
        $ns duplex-link $n $cluster($n) 1Mb 5ms DropTail
    }
}

# Eavesdroppers only linked to Cluster Heads
$ns duplex-link $eav1 $ch1 1Mb 5ms DropTail
$ns duplex-link $eav2 $ch2 1Mb 5ms DropTail

# Select Random Normal Nodes to Act as Jammers
set jam1 $node([expr {int(rand() * 10)}])
set jam2 $node([expr {int(rand() * 10)}])
while {$jam1 == $ch1 || $jam1 == $ch2 || $jam1 == $eav1 || $jam1 == $eav2} {
    set jam1 $node([expr {int(rand() * 10)}])
}
while {$jam2 == $ch1 || $jam2 == $ch2 || $jam2 == $eav1 || $jam2 == $eav2 || $jam2 == $jam1} {
    set jam2 $node([expr {int(rand() * 10)}])
}

# Jamming Mechanism using Normal Nodes as Jammers
proc activate_jamming {jam eav ch} {
    global ns
    
    $ns at 1.5 "$jam color Purple"
    $ns at 1.5 "$eav color Red"
    $ns rtmodel-at 1.5 down $eav $ch
    
    set udp [new Agent/UDP]
    set cbr [new Application/Traffic/CBR]
    $cbr attach-agent $udp
    $ns attach-agent $jam $udp

    set sink [new Agent/Null]
    $ns attach-agent $eav $sink
    $ns connect $udp $sink

    $cbr set packetSize_ 1024
    $cbr set interval_ 0.001

    $ns at 1.5 "$cbr start"
    $ns at 2.0 "$cbr stop"

    $ns at 2.0 "$jam color Black"
    $ns at 2.0 "$eav color Yellow"
    $ns rtmodel-at 2.0 up $eav $ch
}

activate_jamming $jam1 $eav1 $ch1
activate_jamming $jam2 $eav2 $ch2

proc calculate_SINR {node interferer noise} {
    global sinr_tracefile ns node_pos TRANSMISSION_RANGE jam_packet_count cluster ch1 ch2 jam1 jam2

    # Check if node and interferer positions exist
    if {![info exists node_pos($node)] || ![info exists node_pos($interferer)]} {
        return  ;# Skip SINR calculation if positions are missing
    }

    set node_pos_x [lindex $node_pos($node) 0]
    set node_pos_y [lindex $node_pos($node) 1]
    set interferer_pos_x [lindex $node_pos($interferer) 0]
    set interferer_pos_y [lindex $node_pos($interferer) 1]

    set distance [expr sqrt(pow(($node_pos_x - $interferer_pos_x), 2) + pow(($node_pos_y - $interferer_pos_y), 2))]
    set P_signal [expr 10 - 10 * log10($distance)]

    # Add jamming interference if jamming is active
    set P_interference [expr 5 - 10 * log10($distance)]
    if {[$ns now] >= 1.5 && [$ns now] <= 2.0} {
        set P_interference [expr $P_interference + 20]  ;# Increase interference during jamming
    }
    
    set k 1.38e-23
    set T 290
    set B 1e6
    set noise [expr $k * $T * $B]
    set P_noise $noise

    set SINR [expr $P_signal / ($P_interference + $P_noise)]

    # Determine Cluster Head ID
    if {[info exists cluster($node)]} {
        set cluster_head_id [$cluster($node) id]
    } else {
        set cluster_head_id "N/A"  ;# If the node is not associated with a cluster head
    }

    # Determine Jamming Status
    if {[$ns now] >= 1.5 && [$ns now] <= 2.0} {
        set jamming_status "Active"
    } else {
        set jamming_status "Inactive"
    }

    # Format SINR to 3 decimal places
    set SINR_formatted [format "%.3f" $SINR]

    # Write SINR results to the trace file with node ID, cluster head ID, jamming status, and SINR
    puts $sinr_tracefile "Time: [$ns now], Node ID: [$node id], Cluster Head ID: $cluster_head_id, Jamming Status: $jamming_status, SINR: $SINR_formatted dB"
}
# Schedule SINR Calculation at Regular Intervals
proc schedule_SINR {ns nodes_list} {
    global sinr_log_interval
    set sinr_log_interval 0.1  ;# Log every 0.1s

    foreach n $nodes_list {
        foreach i $nodes_list {
            if {$n != $i} {
                calculate_SINR $n $i 0.1
            }
        }
    }
    $ns at [expr [$ns now] + $sinr_log_interval] "schedule_SINR $ns \"$nodes_list\""
}

# Include eavesdroppers and jammers in the nodes list
set all_nodes [concat $nodes $eav1 $eav2 $jam1 $jam2]

# Initialize node positions (example positions, adjust as needed)
for {set i 0} {$i < 10} {incr i} {
    set node_pos($node($i)) [list [expr rand() * 100] [expr rand() * 100]]
}
set node_pos($eav1) [list [expr rand() * 100] [expr rand() * 100]]
set node_pos($eav2) [list [expr rand() * 100] [expr rand() * 100]]
set node_pos($jam1) [list [expr rand() * 100] [expr rand() * 100]]
set node_pos($jam2) [list [expr rand() * 100] [expr rand() * 100]]

# Start SINR Calculation Scheduling
$ns at 0.1 "schedule_SINR $ns \"$all_nodes\""

# Enable TCP Packet Transmission between Cluster Heads and Base Station
foreach ch [list $ch1 $ch2] {
    set tcp [new Agent/TCP]
    set sink [new Agent/TCPSink]
    $ns attach-agent $ch $tcp
    $ns attach-agent $bs $sink
    $ns connect $tcp $sink

    set ftp [new Application/FTP]
    $ftp attach-agent $tcp

    # Start FTP at 0.2s and stop at 9.9s
    $ns at 0.2 "$ftp start"
    $ns at 9.9 "$ftp stop"
}

# CBR Traffic from Normal Nodes to Cluster Heads
foreach n $nodes {
    if {$n != $ch1 && $n != $ch2} {
        set udp [new Agent/UDP]
        set cbr [new Application/Traffic/CBR]
        $cbr attach-agent $udp

        $ns attach-agent $n $udp
        set sink [new Agent/Null]
        $ns attach-agent $cluster($n) $sink

        $ns connect $udp $sink

        $cbr set packetSize_ 512
        $cbr set interval_ 0.01

        $ns at 0.1 "$cbr start"
    }
}

# Start Simulation and Finish Process
$ns at 10.0 "finish"

proc finish {} {
    global ns tracefile namfile sinr_tracefile
    close $tracefile
    close $namfile
    close $sinr_tracefile
    puts "Simulation Completed!"
    exit 0
}

$ns run
