#!/usr/bin/env groovy
node {
  properties([disableConcurrentBuilds()])

  try {

    def project        = "fork-okta-spring-boot-sample"
    def dockerRepo     = "192.168.137.128:18080"
    def imagePrefix    = "ci"
    def dockerFile     = "Dockerfile"
    def imageName      = "${dockerRepo}/${imagePrefix}/${project}"
    def buildNumber    = env.BUILD_NUMBER
    def branchName  = env.BRANCH_NAME ?: "main"


    def k8sProjectName = "fork-okta-spring-boot-sample"
    def namespace      = "default"


    def NEXUS_MIRROR   = "http://192.168.137.128:8081/repository/maven-central/"
	def dockerCredId   = "Harbor" 
	def SONAR_SERVER = "SonarQube" 

    stage('Workspace Clearing') { cleanWs() }

    stage('Checkout code') {
	checkout scm
	sh """
    git fetch --all --prune
    git checkout -B ${branchName} origin/${branchName}
    git reset --hard origin/${branchName}
	"""
}



    stage('Prepare Maven settings (Nexus)') {
      sh 'mkdir -p .mvn'
      writeFile file: '.mvn/settings-nexus.xml', text: """
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
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
  <activeProfiles><activeProfile>nexus</activeProfile></activeProfiles>
</settings>
"""
    }

stage('Unit test + SonarQube Analysis') {
  withSonarQubeEnv('SonarQube') { // đúng tên server bạn khai báo
    sh '''#!/bin/bash -e
      chmod +x mvnw
      # Kiểm tra env đã được inject
      test -n "$SONAR_HOST_URL" && test -n "$SONAR_AUTH_TOKEN" || { echo "Missing SONAR env"; exit 2; }
      echo "[OK] SONAR_HOST_URL=$SONAR_HOST_URL"
      echo "[OK] SONAR_TOKEN length: ${#SONAR_AUTH_TOKEN}"

      docker run --rm \
        -e SONAR_HOST_URL="$SONAR_HOST_URL" \
        -e SONAR_TOKEN="$SONAR_AUTH_TOKEN" \
        -v "$PWD:/ws" -w /ws \
        -v "$HOME/.m2:/root/.m2" \
        eclipse-temurin:21-jdk bash -lc '
          ./mvnw -U -B -s .mvn/settings-nexus.xml \
            clean verify \
            org.sonarsource.scanner.maven:sonar-maven-plugin:4.0.0.4121:sonar \
            -Dsonar.host.url="$SONAR_HOST_URL" \
            -Dsonar.token="$SONAR_TOKEN" \
            -Dsonar.projectKey=fork-okta-spring-boot-sample \
            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
        '
    '''
  }
  junit 'target/surefire-reports/*.xml'
}

    stage('Quality Gate') {
      timeout(time: 10, unit: 'MINUTES') {
        def qg = waitForQualityGate()
        if (qg.status != 'OK') {
          error "Quality Gate failed: ${qg.status}"
        }
      }
    }
	stage('Add OTel agent to context') {
	sh '''
    mkdir -p otel
    cp /opt/otel/opentelemetry-javaagent.jar otel/opentelemetry-javaagent.jar
    ls -lh otel/
	'''
}
    stage('Docker Build') {
      sh "docker build -t ${imageName}:${branchName} -f ${dockerFile} ."
    }

	stage('Push Image') {
      withEnv(['DOCKER_CONFIG=.docker']) {
        sh 'mkdir -p .docker && echo "{}" > .docker/config.json'
        withCredentials([usernamePassword(credentialsId: dockerCredId, usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
          sh """
            set -e
            docker logout 192.168.137.128:18080 || true
            echo "\$REG_PASS" | docker login 192.168.137.128:18080 --username "\$REG_USER" --password-stdin
            docker push ${imageName}:${branchName}
            docker tag  ${imageName}:${branchName} ${imageName}:${branchName}-build-${buildNumber}
            docker push ${imageName}:${branchName}-build-${buildNumber}
            docker logout 192.168.137.128:18080 || true
          """
        }
      }
    }



    def imageBuild = "${imageName}:${branchName}-build-${buildNumber}"
    echo "Pushed: ${imageBuild}"

    stage('Deploy to K8s') {
      sh """#!/bin/bash -e
        echo "Deploying ${imageBuild} to ${namespace}/${k8sProjectName}"
        kubectl -n ${namespace} get deploy ${k8sProjectName} -o name
        kubectl -n ${namespace} set image deployment/${k8sProjectName} ${k8sProjectName}=${imageBuild}
        kubectl -n ${namespace} rollout status deployment/${k8sProjectName}
      """
    }

  } catch (e) {
    currentBuild.result = "FAILED"
    throw e
  }
}