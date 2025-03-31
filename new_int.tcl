# Initialize NS2 Simulator
set ns [new Simulator]

# Open the trace file
set tracefile [open out.tr w]
$ns trace-all $tracefile

# Open the NAM trace file
set nf [open out.nam w]
$ns namtrace-all $nf

# Open a file to store SINR values
set sinr_tracefile [open sinr_results.tr w]

# Load SHA-256 package for authentication
package require Tcl 8.5
package require sha256

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
set min_distance 10  ;# Minimum required distance between nodes

# Secure Key for encryption/decryption
set SECRET_KEY 12345  ;# Shared secret key

# Create nodes (20 nodes including CHs)
set num_nodes 20
set nodes {}
array set node_pos {}  ;# Store node positions
array set node_csi {}  ;# Store node CSI values
set total_csi 0

# Function to calculate distance between two points
proc distance {x1 y1 x2 y2} {
    return [expr sqrt(pow(($x1 - $x2), 2) + pow(($y1 - $y2), 2))]
}

# Set up nodes with non-overlapping positions
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

    # Create node and assign position
    set node_array($i) [$ns node]
    $node_array($i) set X_ $x
    $node_array($i) set Y_ $y
    $node_array($i) set Z_ 0.0
    set node_pos($i) "$x $y"
    lappend nodes $node_array($i)

    # Assign CSI values
    set csi [expr 0.5 + rand() * 1.0]  ;# Random CSI between 0.5 and 1.5
    set node_csi($i) $csi
    set total_csi [expr $total_csi + $csi]
}

# Compute dynamic authentication threshold
set avg_csi [expr $total_csi / $num_nodes]
set AUTHENTICATION_THRESHOLD [expr 0.7 * $avg_csi]  ;# Dynamic threshold

# Define the Base Station (BS)
set base_station [$ns node]
$base_station color $BS_color
puts "Base Station assigned: Node BS"

# Function to calculate MNR values using weighted factors
proc computeMNR {node_id x1 y1 bs_x bs_y} {
    set initial_energy [expr 100 + rand() * 50]  ;# Random initial energy (100-150)
    set energy_after_tx [expr $initial_energy - (rand() * 10)]  ;# Energy after transmission
    set energy_consumption [expr $initial_energy - $energy_after_tx]
    set energy_factor [expr $energy_after_tx - $energy_consumption]

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
    # Get node positions
    set x [lindex $node_pos($i) 0]
    set y [lindex $node_pos($i) 1]

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
    $node_array($ch) color $CH_color
}

# Secure Encryption and Decryption Functions
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

# Array to store node colors
array set node_color {}

# Assign members to the nearest CH with enhanced authentication
puts "\nNode Assignments:"
foreach node_idx {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19} {
    set mnr_value [lindex [lsearch -inline -index 0 $MNR_values $node_idx] 1]

    if {[lsearch -exact $cluster_heads $node_idx] != -1} {
        puts [format "Node %d: Role = Cluster Head, CH = Self, MNR = %.4f" $node_idx $mnr_value]
        $node_array($node_idx) color $CH_color
        set node_color($node_idx) $CH_color
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
        $node_array($node_idx) color $Cluster1_color
        set node_color($node_idx) $Cluster1_color
        set cluster_name "Cluster 1 (Brown)"
    } elseif {$cluster_index == 1} {
        $node_array($node_idx) color $Cluster2_color
        set node_color($node_idx) $Cluster2_color
        set cluster_name "Cluster 2 (Yellow)"
    } elseif {$cluster_index == 2} {
        $node_array($node_idx) color $Cluster3_color
        set node_color($node_idx) $Cluster3_color
        set cluster_name "Cluster 3 (Blue)"
    }

    # Enhanced authentication with encryption and hashing
    set encrypted_csi [encrypt_csi $node_csi($node_idx) $SECRET_KEY]
    set auth_token [generate_hash $node_idx $encrypted_csi $SECRET_KEY]
    set decrypted_csi [decrypt_csi $encrypted_csi $SECRET_KEY]
    set ch_csi_val $node_csi($chosen_CH)
    set diff [expr abs($decrypted_csi - $ch_csi_val)]
    set expected_token [generate_hash $node_idx $encrypted_csi $SECRET_KEY]

    puts [format "Node %d: Role = Cluster Member, CH = %d, MNR = %.4f, Assigned to %s" $node_idx $chosen_CH $mnr_value $cluster_name]

    if {$min_dist < $TRANSMISSION_RANGE && $diff <= $AUTHENTICATION_THRESHOLD && $auth_token eq $expected_token} {
        puts "Node $node_idx -> Cluster Head $chosen_CH: ✅ Accepted (Secure Auth)"
        $ns duplex-link $node_array($node_idx) $node_array($chosen_CH) 1Mb 10ms DropTail
    } else {
        puts "Node $node_idx -> Cluster Head $chosen_CH: ❌ Denied (Security Check Failed)"
        $node_array($node_idx) color $Denied_color
        set node_color($node_idx) $Denied_color
        $ns at 0.5 "$node_array($node_idx) label Untrusted"
    }
}

# Connect CHs to the Base Station
foreach ch $cluster_heads {
    $ns duplex-link $node_array($ch) $base_station 2Mb 5ms DropTail
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
set jam1 $node_array([expr {int(rand() * $num_nodes)}])
set jam2 $node_array([expr {int(rand() * $num_nodes)}])

# Ensure jammers are not CHs or the same node
while {[lsearch -exact $cluster_heads [$jam1 id]] != -1 || [lsearch -exact $cluster_heads [$jam2 id]] != -1 || $jam1 == $jam2} {
    set jam1 $node_array([expr {int(rand() * $num_nodes)}])
    set jam2 $node_array([expr {int(rand() * $num_nodes)}])
}

# Assign positions to jammers
set jam1_pos_x [expr rand() * 150]
set jam1_pos_y [expr rand() * 150]
set node_pos($jam1) [list $jam1_pos_x $jam1_pos_y]

set jam2_pos_x [expr rand() * 150]
set jam2_pos_y [expr rand() * 150]
set node_pos($jam2) [list $jam2_pos_x $jam2_pos_y]

# Eavesdroppers only linked to Cluster Heads
$ns duplex-link $eav1 $node_array([lindex $cluster_heads 0]) 1Mb 5ms DropTail
$ns duplex-link $eav2 $node_array([lindex $cluster_heads 1]) 1Mb 5ms DropTail

# Enhanced Jamming Mechanism with Authentication Awareness
proc activate_jamming {jam eav ch} {
    global ns Jamming_color node_color jam_packet_count Eavesdropper_color
    global Cluster1_color Cluster2_color Cluster3_color

    # Ensure the jammer node has a valid color
    if {![info exists node_color([$jam id])]} {
        set node_color([$jam id]) $Cluster1_color
    }

    # Change colors to indicate jamming activation
    $ns at 1.5 "$jam color $Jamming_color"
    $ns at 1.5 "$eav color Red"
    $ns rtmodel-at 1.5 down $eav $ch

    # Create UDP and CBR agents for jamming traffic
    set udp [new Agent/UDP]
    set cbr [new Application/Traffic/CBR]
    $cbr attach-agent $udp
    $ns attach-agent $jam $udp

    set sink [new Agent/Null]
    $ns attach-agent $eav $sink
    $ns connect $udp $sink

    $cbr set packetSize_ 1024
    $cbr set interval_ 0.001
    $cbr set fid_ 3
    $ns color 3 Purple

    $ns at 1.5 "$cbr start"
    $ns at 2.0 "$cbr stop"
    $ns at 2.0 "$jam color $node_color([$jam id])"
    $ns at 2.0 "$eav color $Eavesdropper_color"
    $ns rtmodel-at 2.0 up $eav $ch

    puts "Jamming activated for [$jam id] targeting [$eav id] via [$ch id] at 1.5s"
    puts "Jamming deactivated for [$jam id] at 2.0s"
}

# Activate Jamming
activate_jamming $jam1 $eav1 $node_array([lindex $cluster_heads 0])
activate_jamming $jam2 $eav2 $node_array([lindex $cluster_heads 1])

# Assign UDP traffic for all nodes (excluding denied nodes)
foreach node_idx {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19} {
    if {[lsearch -exact $cluster_heads $node_idx] != -1} {
        continue
    }

    # Skip traffic generation for denied nodes
    if {[info exists node_color($node_idx)] && $node_color($node_idx) == $Denied_color} {
        puts "Node $node_idx is denied and will not generate traffic."
        continue
    }

    set ch_idx [lindex $cluster_heads [expr $node_idx % 3]]

    set udp($node_idx) [new Agent/UDP]
    $ns attach-agent $node_array($node_idx) $udp($node_idx)

    set null($node_idx) [new Agent/Null]
    $ns attach-agent $node_array($ch_idx) $null($node_idx)

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
    $ns attach-agent $node_array($ch) $tcp($ch)

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

# SINR Calculation with Enhanced Metrics
proc calculate_SINR {src_node_obj interferer_node_obj noise} {
    global sinr_tracefile ns node_pos TRANSMISSION_RANGE jam_packet_count cluster_heads node_array
    
    # Get node IDs from the objects
    set src_node [$src_node_obj id]
    set interferer_node [$interferer_node_obj id]

    # Check if node and interferer positions exist
    if {![info exists node_pos($src_node)] || ![info exists node_pos($interferer_node)]} {
        return  ;# Skip SINR calculation if positions are missing
    }

    set src_node_pos_x [lindex $node_pos($src_node) 0]
    set src_node_pos_y [lindex $node_pos($src_node) 1]
    set interferer_pos_x [lindex $node_pos($interferer_node) 0]
    set interferer_pos_y [lindex $node_pos($interferer_node) 1]

    set distance [expr sqrt(pow(($src_node_pos_x - $interferer_pos_x), 2) + pow(($src_node_pos_y - $interferer_pos_y), 2))]
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

    set SINR [expr $P_signal / ($P_interference + $noise)]

    # Determine Cluster Head ID
    set cluster_head_id "N/A"
    foreach ch $cluster_heads {
        if {$src_node_obj == $node_array($ch)} {
            set cluster_head_id $ch
            break
        }
    }

    # Determine Jamming Status
    if {[$ns now] >= 1.5 && [$ns now] <= 2.0} {
        set jamming_status "Active"
    } else {
        set jamming_status "Inactive"
    }

    # Format SINR to 3 decimal places
    set SINR_formatted [format "%.3f" $SINR]

    # Write SINR results to the trace file
    puts $sinr_tracefile "Time: [$ns now], Node ID: $src_node, Cluster Head ID: $cluster_head_id, Jamming Status: $jamming_status, SINR: $SINR_formatted dB"
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

# Include all nodes in SINR calculation
set all_nodes [concat $nodes $eav1 $eav2 $jam1 $jam2]
$ns at 0.1 "schedule_SINR $ns \"$all_nodes\""

# Define a 'finish' procedure
proc finish {} {
    global ns nf sinr_tracefile tracefile
    $ns flush-trace
    close $nf
    close $sinr_tracefile
    close $tracefile
    exec nam out.nam &
    puts "Simulation Completed!"
    exit 0
}

# Schedule simulation termination
$ns at 5.0 "finish"

# Run simulation
$ns run
