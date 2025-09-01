pipeline {
    agent any

    environment {
        TF_DIR         = 'terraform'
        ANSIBLE_DIR    = 'ansible'
        INVENTORY_FILE = "${ANSIBLE_DIR}/inventory.ini"
    }

    stages {
        stage('Checkout pipeline repo') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-creds',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        cd ${TF_DIR}
                        terraform init -input=false
                        terraform apply -auto-approve -input=false
                    '''
                }
            }
        }

        stage('Generate Inventory') {
            steps {
                script {
                    // Get EC2 public IP from Terraform
                    def ec2_ip = sh(
                        script: "cd ${TF_DIR} && terraform output -raw public_ip",
                        returnStdout: true
                    ).trim()
                    echo "✅ EC2 Public IP is: ${ec2_ip}"

                    // Build inventory content
                    def inventoryContent = """[ec2]
ec2-server ansible_host=${ec2_ip}
"""

                    // Ensure ansible dir exists
                    sh "mkdir -p ${ANSIBLE_DIR}"

                    // Write (overwrite) ansible/inventory.ini
                    writeFile file: "${ANSIBLE_DIR}/inventory.ini", text: inventoryContent

                    echo "✅ Updated ansible/inventory.ini with EC2 IP: ${ec2_ip}"
                }
            }
        }

        stage('Check Ansible Ping') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'abc-ssh',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    withEnv(["ANSIBLE_HOST_KEY_CHECKING=False"]) {
                        script {
                            // Retry logic
                            def maxRetries = 10
                            def retryDelay = 15 // seconds
                            def success = false

                            for (int i = 1; i <= maxRetries; i++) {
                                echo "🔄 Trying Ansible ping... Attempt ${i} of ${maxRetries}"
                                try {
                                    sh """
                                        ansible -i ansible/inventory.ini ec2 -m ping \
                                        --private-key ${SSH_KEY} \
                                        -u ${SSH_USER}
                                    """
                                    echo "EC2 is reachable! Moving on..."
                                    success = true
                                    break
                                } catch (err) {
                                    echo "EC2 not ready yet. Waiting ${retryDelay} seconds..."
                                    sleep retryDelay
                                }
                            }

                            if (!success) {
                                error "EC2 did not become reachable after ${maxRetries} attempts!"
                            }
                        }
                    }
                }
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'abc-ssh',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    withEnv(["ANSIBLE_HOST_KEY_CHECKING=False"]) {
                        sh '''
                            ansible-playbook -i ansible/inventory.ini ansible/main.yml \
                            --private-key ${SSH_KEY} \
                            -u ${SSH_USER}
                        '''
                    }
                }
            }
        }

        stage('Website URL') {
            steps {
                script {
                    def site_url = sh(
                        script: "terraform -chdir=terraform output -raw public_dns",
                        returnStdout: true
                    ).trim()
                    echo "Your website is live at: http://${site_url}"
                }
            }
        }
    }
}
