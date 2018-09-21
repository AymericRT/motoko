pipeline {
    agent any
    stages {
        stage ('git submodule') {
            steps {
                sh 'git submodule update --init --recursive'
            }
            steps {
                sh 'git clone --recursive git@github.com:dfinity-lab/dev-in-nix nix/dev-in-nix'
            }
        }

        stage('Build and test (native)') {
            steps {
                sh 'nix-build -A native --arg test-dsh true'
            }
        }
        stage('Build and test (js)') {
            steps {
                sh 'nix-build -A js'
            }
        }
    }
    // Workspace Cleanup plugin
    post {
        always {
            cleanWs()
        }
    }
}
