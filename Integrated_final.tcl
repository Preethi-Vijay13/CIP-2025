# Initialize NS2 Simulator
set ns [new Simulator]

# Define colors for different node types
set BS_color Red
set CH_color Green
set Cluster1_color Brown
set Cluster2_color Yellow
set Cluster3_color Blue
set Denied_color Black  ;# Color for denied nodes
set Jamming_color Purple ;# Color for jamming nodes
set Eavesdropper_color Pink ;# Color for eavesdroppers

# Set transmission range
set TRANSMISSION_RANGE 150  ;# Nodes must be within 150 units to communicate

# Open the NAM trace file
set nf [open out.nam w]
$ns namtrace-all $nf

# Open a file to store SINR values
set sinr_tracefile [open sinr_results.tr w]

# Define a 'finish' procedure
proc finish {} {
    global ns nf sinr_tracefile
    $ns flush-trace
    close $nf
    close $sinr_tracefile
    exec nam out.nam &
    puts "Simulation Completed!"
    exit 0
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

# Create nodes (20 nodes including CHs)
set num_nodes 20
set nodes {}
for {set i 0} {$i < $num_nodes} {incr i} {
    set node($i) [$ns node]
    $node($i) set address_ $i  ;# Set node addresses
    lappend nodes $node($i)
}

# Initialize CSI values for nodes using a realistic range (e.g., Rayleigh fading)
set total_csi 0
array set node_csi {}
for {set i 0} {$i < $num_nodes} {incr i} {
    set csi [expr 0.5 + rand() * 1.0]  ;# CSI range: 0.5 to 1.5
    set node_csi($i) $csi
    set total_csi [expr $total_csi + $csi]
}

# Compute dynamic authentication threshold
set avg_csi [expr $total_csi / $num_nodes]
set AUTHENTICATION_THRESHOLD [expr 0.5 * $avg_csi]  ;# 70% of average CSI

# Define the Base Station (BS)
set base_station [$ns node]
$base_station color $BS_color
puts "Base Station assigned: Node BS"

# Function to calculate MNR values using weighted factors
proc computeMNR {node_id x1 y1 bs_x bs_y} {
    set initial_energy [expr 100 + rand() * 50]  ;# Random initial energy (100-150)
    set energy_after_tx [expr $initial_energy - (rand() * 10)]  ;# Energy after transmission
    set energy_consumption [expr $initial_energy - $energy_after_tx]
    set energy_factor [expr $energy_after_tx - $energy_consumption]  ;# Ensuring energy is factored correctly

    set coverage [expr rand() * 10]  ;# Random coverage (0-10)
    set distance [expr sqrt(pow(($x1 - $bs_x),2) + pow(($y1 - $bs_y),2))]  ;# Euclidean distance
    set mobility [expr rand() * 5]   ;# Random mobility (0-5)

    # Weight factors (tuned for realistic scenarios)
    set w1 0.4  ;# Weight for energy factor
    set w2 0.3  ;# Weight for coverage
    set w3 0.2  ;# Weight for distance
    set w4 0.1  ;# Weight for mobility

    # Compute MNR using weighted factors
    set MNR [expr ($w1 * $energy_factor) + ($w2 * $coverage) + ($w3 * $distance) + ($w4 * $mobility)]

    return $MNR
}

# Compute MNR values for all nodes
set MNR_values {}
for {set i 0} {$i < $num_nodes} {incr i} {
    # Assign random positions for nodes
    set x [expr rand() * 150]  ;# Adjust the range to ensure nodes are closer
    set y [expr rand() * 150]
    set node_pos($i) [list $x $y]

    # Compute MNR based on node positions
    set MNR_val [computeMNR $i $x $y 250 250]  ;# Assuming BS is at (250,250)
    lappend MNR_values [list $i $MNR_val]
}

# Sort nodes based on MNR values (highest first) and select top 3 as CHs
set sorted_MNR [lsort -real -index 1 -decreasing $MNR_values]
set cluster_heads {}
for {set i 0} {$i < 3} {incr i} {
    lappend cluster_heads [lindex $sorted_MNR $i 0]
}

puts "\nSelected Cluster Heads:"
foreach ch $cluster_heads {
    set ch_mnr [lindex [lsearch -inline -index 0 $MNR_values $ch] 1]
    puts [format "Node %d: Cluster Head, MNR = %.4f" $ch $ch_mnr]

    $node($ch) color $CH_color
}

# Array to store node colors
array set node_color {}

# Assign members to the nearest CH based on actual Euclidean distance
puts "\nNode Assignments:"
foreach node_idx {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19} {
    set mnr_value [lindex [lsearch -inline -index 0 $MNR_values $node_idx] 1]

    if {[lsearch -exact $cluster_heads $node_idx] != -1} {
        puts [format "Node %d: Role = Cluster Head, CH = Self, MNR = %.4f" $node_idx $mnr_value]
        $node($node_idx) color $CH_color
        set node_color($node_idx) $CH_color  ;# Store color in array
        continue
    }

    set min_dist 100000
    set chosen_CH -1
    foreach ch $cluster_heads {
        set ch_x [lindex $node_pos($ch) 0]
        set ch_y [lindex $node_pos($ch) 1]
        set node_x [lindex $node_pos($node_idx) 0]
        set node_y [lindex $node_pos($node_idx) 1]
        set dist [expr sqrt(pow(($node_x - $ch_x),2) + pow(($node_y - $ch_y),2))]
        if {$dist < $min_dist} {
            set min_dist $dist
            set chosen_CH $ch
        }
    }

    set cluster_index [lsearch -exact $cluster_heads $chosen_CH]
    if {$cluster_index == 0} {
        $node($node_idx) color $Cluster1_color
        set node_color($node_idx) $Cluster1_color  ;# Store color in array
        set cluster_name "Cluster 1 (Brown)"
    } elseif {$cluster_index == 1} {
        $node($node_idx) color $Cluster2_color
        set node_color($node_idx) $Cluster2_color  ;# Store color in array
        set cluster_name "Cluster 2 (Yellow)"
    } elseif {$cluster_index == 2} {
        $node($node_idx) color $Cluster3_color
        set node_color($node_idx) $Cluster3_color  ;# Store color in array
        set cluster_name "Cluster 3 (Blue)"
    }

    puts [format "Node %d: Role = Cluster Member, CH = %d, MNR = %.4f, Assigned to %s" $node_idx $chosen_CH $mnr_value $cluster_name]

    set node_csi_val $node_csi($node_idx)
    set ch_csi_val $node_csi($chosen_CH)
    set diff [expr abs($node_csi_val - $ch_csi_val)]

    if {$min_dist < $TRANSMISSION_RANGE && $diff <= $AUTHENTICATION_THRESHOLD} {
        puts "Node $node_idx -> Cluster Head $chosen_CH: ✅ Accepted (Distance: $min_dist, CSI Diff: $diff)"
        $ns duplex-link $node($node_idx) $node($chosen_CH) 1Mb 10ms DropTail
    } else {
        puts "Node $node_idx -> Cluster Head $chosen_CH: ❌ Denied (Distance: $min_dist, CSI Diff: $diff)"
        $node($node_idx) color $Denied_color
        set node_color($node_idx) $Denied_color  ;# Store color in array
        $ns at 0.5 "$node($node_idx) label Untrusted"
    }
}

# Connect CHs to the Base Station
foreach ch $cluster_heads {
    $ns duplex-link $node($ch) $base_station 2Mb 5ms DropTail
}

# Assign UDP traffic for all nodes (excluding denied nodes)
foreach node_idx {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19} {
    if {[lsearch -exact $cluster_heads $node_idx] != -1} {
        continue
    }

    # Skip traffic generation for denied nodes
    if {$node_color($node_idx) == $Denied_color} {
        puts "Node $node_idx is denied and will not generate traffic."
        continue
    }

    set ch_idx [lindex $cluster_heads [expr $node_idx % 3]]

    set udp($node_idx) [new Agent/UDP]
    $ns attach-agent $node($node_idx) $udp($node_idx)

    set null($node_idx) [new Agent/Null]
    $ns attach-agent $node($ch_idx) $null($node_idx)

    $ns connect $udp($node_idx) $null($node_idx)
    $udp($node_idx) set fid_ 1  ;# Accepted nodes (normal traffic)

    set cbr($node_idx) [new Application/Traffic/CBR]
    $cbr($node_idx) attach-agent $udp($node_idx)
    $cbr($node_idx) set type_ CBR
    $cbr($node_idx) set packet_size_ 512
    $cbr($node_idx) set rate_ 512kb
    $cbr($node_idx) set random_ false

    $ns at 0.1 "$cbr($node_idx) start"
    $ns at 4.5 "$cbr($node_idx) stop"
}

# Assign TCP traffic from CHs to the Base Station
foreach ch $cluster_heads {
    set tcp($ch) [new Agent/TCP]
    $tcp($ch) set class_ 2
    $ns attach-agent $node($ch) $tcp($ch)

    set sink($ch) [new Agent/TCPSink]
    $ns attach-agent $base_station $sink($ch)

    $ns connect $tcp($ch) $sink($ch)
    $tcp($ch) set fid_ 2

    set ftp($ch) [new Application/FTP]
    $ftp($ch) attach-agent $tcp($ch)
    $ftp($ch) set type_ FTP

    $ns at 1.0 "$ftp($ch) start"
    $ns at 4.0 "$ftp($ch) stop"
}

# Jamming Mechanism
set jam_packet_count 0

proc activate_jamming {jam eav ch} {
    global ns Jamming_color node_color jam_packet_count Eavesdropper_color

    # Ensure the jammer node has a valid color
    if {![info exists node_color($jam)]} {
        set node_color($jam) $Cluster1_color  ;# Default color if not assigned
    }

    $ns at 1.5 "$jam color $Jamming_color"
    $ns at 1.5 "$eav color Red"
    $ns rtmodel-at 1.5 down $eav $ch
   
    set udp [new Agent/UDP]
    set cbr [new Application/Traffic/CBR]
    $cbr attach-agent $udp
    $ns attach-agent $jam $udp

    set sink [new Agent/Null]
    $ns attach-agent $eav $sink
    $ns connect $udp $sink

    $cbr set packetSize_ 512
    $cbr set interval_ 0.01

    $ns at 1.5 "$cbr start"
    $ns at 2.0 "$cbr stop"

    $ns at 2.0 "$jam color $node_color($jam)"
    $ns at 2.0 "$eav color $Eavesdropper_color"
    $ns rtmodel-at 2.0 up $eav $ch
    
    puts "Jamming activated for $jam targeting $eav at 1.5s"
    puts "Jamming deactivated for $jam at 2.0s"
}

# Define Eavesdroppers (Only linked to CHs)
set eav1 [$ns node]
set eav2 [$ns node]
$eav1 color $Eavesdropper_color
$eav2 color $Eavesdropper_color

# Assign positions to eavesdroppers
set eav1_pos_x [expr rand() * 150]
set eav1_pos_y [expr rand() * 150]
set node_pos($eav1) [list $eav1_pos_x $eav1_pos_y]

set eav2_pos_x [expr rand() * 150]
set eav2_pos_y [expr rand() * 150]
set node_pos($eav2) [list $eav2_pos_x $eav2_pos_y]


# Select Random Normal Nodes to Act as Jammers (excluding cluster heads)
set jam1 $node([expr {int(rand() * $num_nodes)}])
set jam2 $node([expr {int(rand() * $num_nodes)}])

# Assign positions to jammers
set jam1_pos_x [expr rand() * 150]
set jam1_pos_y [expr rand() * 150]
set node_pos($jam1) [list $jam1_pos_x $jam1_pos_y]

set jam2_pos_x [expr rand() * 150]
set jam2_pos_y [expr rand() * 150]
set node_pos($jam2) [list $jam2_pos_x $jam2_pos_y]

while {[lsearch -exact $cluster_heads $jam1] != -1 || [lsearch -exact $cluster_heads $jam2] != -1 || $jam1 == $jam2 || [shortest_path $jam1 $eav1] > $TRANSMISSION_RANGE || [shortest_path $jam2 $eav2] > $TRANSMISSION_RANGE} {
    set jam1 $node([expr {int(rand() * $num_nodes)}])
    set jam2 $node([expr {int(rand() * $num_nodes)}])
}

# Assign Colors to Jammer Nodes
foreach jam_node [list $jam1 $jam2] {
    if {![info exists node_color($jam_node)]} {
        # Assign a default color (e.g., Cluster1_color) if the node is not in the array
        set node_color($jam_node) $Cluster1_color
    }
}


# Eavesdroppers only linked to Cluster Heads
$ns duplex-link $eav1 $node([lindex $cluster_heads 0]) 1Mb 5ms DropTail
$ns duplex-link $eav2 $node([lindex $cluster_heads 1]) 1Mb 5ms DropTail


# Activate Jamming
activate_jamming $jam1 $eav1 $node([lindex $cluster_heads 0])
activate_jamming $jam2 $eav2 $node([lindex $cluster_heads 1])


proc calculate_SINR {node interferer noise} {
    global sinr_tracefile ns node_pos TRANSMISSION_RANGE jam_packet_count

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

    set P_noise $noise

    set SINR [expr $P_signal / ($P_interference + $P_noise)]
    
    # Write SINR results to the trace file
    puts $sinr_tracefile "Time: [$ns now], Node: $node, Interferer: $interferer, SINR: $SINR dB"
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
schedule_SINR $ns "$all_nodes"
schedule_SINR $ns "$nodes"

# Schedule simulation termination
$ns at 5.0 "finish"  ;# Increased simulation time

# Run simulation
$ns run
