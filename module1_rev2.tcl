set ns [new Simulator]
# Define colors for different node types
set BS_color Red
set CH_color Green
set Cluster1_color Brown
set Cluster2_color Orange
set Cluster3_color Blue

# Open the NAM trace file
set nf [open out.nam w]
$ns namtrace-all $nf

# Define a 'finish' procedure
proc finish {} {
    global ns nf
    $ns flush-trace
    close $nf
    exec nam out.nam &
    exit 0
}

# Create nodes (20 nodes including CHs)
set num_nodes 20
set nodes {}
for {set i 0} {$i < $num_nodes} {incr i} {
    set node($i) [$ns node]
    lappend nodes $node($i)
}


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

    # Weight factors (adjustable)
    set w1 0.5  ;# Weight for energy factor
    set w2 0.2  ;# Weight for coverage
    set w3 0.2  ;# Weight for distance
    set w4 0.1  ;# Weight for mobility

    # Compute MNR using only addition
    set MNR [expr ($w1 * $energy_factor) + ($w2 * $coverage) + ($w3 * $distance) + ($w4 * $mobility)]

    return $MNR
}

# Compute MNR values for all nodes
set MNR_values {}
for {set i 0} {$i < $num_nodes} {incr i} {
    # Assign random positions for nodes
    set x [expr rand() * 500]
    set y [expr rand() * 500]

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

# Assign members to the nearest CH based on actual Euclidean distance
puts "\nNode Assignments:"
foreach node_idx {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19} {
    set mnr_value [lindex [lsearch -inline -index 0 $MNR_values $node_idx] 1]

    if {[lsearch -exact $cluster_heads $node_idx] != -1} {
        puts [format "Node %d: Role = Cluster Head, CH = Self, MNR = %.4f" $node_idx $mnr_value]

        continue
    }

    set min_dist 100000
    set chosen_CH -1
    foreach ch $cluster_heads {
        # Retrieve CH position
        set ch_x [expr rand() * 500]  ;# CH x-coordinate
        set ch_y [expr rand() * 500]  ;# CH y-coordinate

        # Retrieve node position
        set node_x [expr rand() * 500]
        set node_y [expr rand() * 500]

        # Compute Euclidean distance
        set dist [expr sqrt(pow(($node_x - $ch_x),2) + pow(($node_y - $ch_y),2))]

        if {$dist < $min_dist} {
            set min_dist $dist
            set chosen_CH $ch
        }
    }

    set cluster_index [lsearch -exact $cluster_heads $chosen_CH]

    # Assign colors based on CH association
    if {$cluster_index == 0} {
        $node($node_idx) color $Cluster1_color
        set cluster_name "Cluster 1 (Brown)"
    } elseif {$cluster_index == 1} {
        $node($node_idx) color $Cluster2_color
        set cluster_name "Cluster 2 (Orange)"
    } elseif {$cluster_index == 2} {
        $node($node_idx) color $Cluster3_color
        set cluster_name "Cluster 3 (Blue)"
    }

    puts [format "Node %d: Role = Cluster Member, CH = %d, MNR = %.4f, Assigned to %s" $node_idx $chosen_CH $mnr_value $cluster_name]


    # Create a link from member to CH
    $ns duplex-link $node($node_idx) $node($chosen_CH) 1Mb 10ms DropTail
}


# Connect CHs to the Base Station
foreach ch $cluster_heads {
    $ns duplex-link $node($ch) $base_station 2Mb 5ms DropTail
}

# Assign UDP traffic for cluster members to CHs
foreach node_idx {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19} {
    if {[lsearch -exact $cluster_heads $node_idx] != -1} {
        continue
    }

    set ch_idx [lindex $cluster_heads [expr $node_idx % 3]]

    set udp($node_idx) [new Agent/UDP]
    $ns attach-agent $node($node_idx) $udp($node_idx)

    set null($node_idx) [new Agent/Null]
    $ns attach-agent $node($ch_idx) $null($node_idx)

    $ns connect $udp($node_idx) $null($node_idx)
    $udp($node_idx) set fid_ 1

    set cbr($node_idx) [new Application/Traffic/CBR]
    $cbr($node_idx) attach-agent $udp($node_idx)
    $cbr($node_idx) set type_ CBR
    $cbr($node_idx) set packet_size_ 512
    $cbr($node_idx) set rate_ 512kb
    $cbr($node_idx) set random_ false
}

# Schedule CBR traffic from members to CHs
foreach node_idx {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19} {
    if {[lsearch -exact $cluster_heads $node_idx] != -1} {
        continue
    }

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

    # Start FTP data transfer from CH to BS
    $ns at 1.0 "$ftp($ch) start"
    $ns at 4.0 "$ftp($ch) stop"
}

# Schedule simulation termination
$ns at 5.0 "finish"

# Run simulation
$ns run
