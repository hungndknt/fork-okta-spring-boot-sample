// Jenkinsfile
pipeline {
  agent any

  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timestamps()
  }

  environment {
    // ====== Tùy chỉnh theo môi trường của bạn ======
    MAVEN_TOOL              = 'apache-maven-3.9.11'          // Tên Maven tool trên Jenkins
    NEXUS_MIRROR            = 'http://192.168.137.128:8081/repository/maven-central/
    REGISTRY                = '192.168.137.128:18080'        // Harbor/registry nội bộ
    IMAGE_NAMESPACE         = 'ci'
    IMAGE_NAME              = 'okta-spring-boot-sample'
    #REGISTRY_CREDENTIALS_ID = 'harbor-cred'                  // Jenkins Credentials (username+password) để login registry
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'mkdir -p .mvn'
      }
    }

    stage('Prepare Maven settings (Nexus mirror)') {
      steps {
        writeFile file: '.mvn/settings-nexus.xml', text: """
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <mirrors>
    <mirror>
      <id>internal-nexus</id>
      <name>Internal Nexus Proxy</name>
      <url>${NEXUS_MIRROR}</url>
      <mirrorOf>*</mirrorOf>
    </mirror>
  </mirrors>
  <profiles>
    <profile>
      <id>nexus</id>
      <repositories>
        <repository>
          <id>central</id>
          <url>${NEXUS_MIRROR}</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
      </repositories>
      <pluginRepositories>
        <pluginRepository>
          <id>central</id>
          <url>${NEXUS_MIRROR}</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>nexus</activeProfile>
  </activeProfiles>
</settings>
"""
      }
    }

    stage('Build JAR (Maven)') {
      steps {
        script {
          def mvnHome = tool name: env.MAVEN_TOOL, type: 'maven'
          env.PATH = "${mvnHome}/bin:${env.PATH}"
        }
        // Build + test; nếu muốn bỏ test: thêm -DskipTests
        sh 'mvn -B -s .mvn/settings-nexus.xml clean package'
      }
      post {
        success {
          archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
        }
      }
    }

    stage('Docker Build') {
      steps {
        script {
          def safeBranch = (env.BRANCH_NAME ?: 'local').replaceAll('[^A-Za-z0-9_.-]','-')
          env.IMAGE_TAG  = "${REGISTRY}/${IMAGE_NAMESPACE}/${IMAGE_NAME}:${safeBranch}-${env.BUILD_NUMBER}"
        }
        sh """
          docker build -t "${IMAGE_TAG}" .
        """
      }
    }

    stage('Docker Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: env.REGISTRY_CREDENTIALS_ID, usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
          sh '''
            echo "$REG_PASS" | docker login ${REGISTRY} --username "$REG_USER" --password-stdin
            docker push "${IMAGE_TAG}"
            docker logout ${REGISTRY} || true
          '''
        }
      }
    }
  }

  post {
    always {
      echo "Built & pushed: ${IMAGE_TAG}"
    }
  }
}
