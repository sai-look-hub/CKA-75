# ============================================
# 7. MAIN MENU
# ============================================

show_menu() {
    cat << EOF

===========================================
DaemonSets & StatefulSets Management
===========================================

DaemonSet Operations:
1.  Create basic DaemonSet
2.  Deploy Node Exporter
3.  Get DaemonSet status
4.  Update DaemonSet image
5.  Verify DaemonSet distribution
6.  Get DaemonSet logs
7.  Watch DaemonSet rollout

StatefulSet Operations:
8.  Create basic StatefulSet
9.  Deploy MongoDB StatefulSet
10. Initialize MongoDB ReplicaSet
11. Scale StatefulSet
12. Get StatefulSet status
13. Verify StatefulSet ordering
14. Test StatefulSet DNS
15. Get StatefulSet logs
16. Watch StatefulSet rollout

Storage Operations:
17. List StatefulSet PVCs
18. Check PVC status
19. Delete StatefulSet with PVCs

Monitoring:
20. Check resource usage
21. List all DaemonSets
22. List all StatefulSets

Backup:
23. Backup StatefulSet

Cleanup:
24. Cleanup demo resources

0. Exit

===========================================
EOF
}

# Run interactive menu
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    while true; do
        show_menu
        read -p "Enter your choice: " choice
        
        case $choice in
            1) read -p "Name: " n; read -p "Namespace: " ns; read -p "Image: " img; create_basic_daemonset $n $ns $img ;;
            2) read -p "Namespace (default: monitoring): " ns; deploy_node_exporter ${ns:-monitoring} ;;
            3) read -p "Name: " n; read -p "Namespace: " ns; get_daemonset_status $n $ns ;;
            4) read -p "Name: " n; read -p "Image: " img; read -p "Namespace: " ns; update_daemonset_image $n $img $ns ;;
            5) read -p "Name: " n; read -p "Namespace: " ns; verify_daemonset_distribution $n $ns ;;
            6) read -p "Name: " n; read -p "Namespace: " ns; get_daemonset_logs $n $ns ;;
            7) read -p "Name: " n; read -p "Namespace: " ns; watch_daemonset_rollout $n $ns ;;
            8) read -p "Name: " n; read -p "Namespace: " ns; read -p "Replicas: " r; create_basic_statefulset $n $ns $r ;;
            9) read -p "Namespace (default: database): " ns; read -p "Replicas (default: 3): " r; deploy_mongodb_statefulset ${ns:-database} ${r:-3} ;;
            10) read -p "Namespace (default: database): " ns; read -p "Replicas (default: 3): " r; initialize_mongodb_replicaset ${ns:-database} ${r:-3} ;;
            11) read -p "Name: " n; read -p "Replicas: " r; read -p "Namespace: " ns; scale_statefulset $n $r $ns ;;
            12) read -p "Name: " n; read -p "Namespace: " ns; get_statefulset_status $n $ns ;;
            13) read -p "Name: " n; read -p "Namespace: " ns; verify_statefulset_ordering $n $ns ;;
            14) read -p "Name: " n; read -p "Namespace: " ns; test_statefulset_dns $n $ns ;;
            15) read -p "Name: " n; read -p "Ordinal (default: 0): " o; read -p "Namespace: " ns; get_statefulset_logs $n ${o:-0} $ns ;;
            16) read -p "Name: " n; read -p "Namespace: " ns; watch_statefulset_rollout $n $ns ;;
            17) read -p
