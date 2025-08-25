#!/usr/bin/env groovy
node {
  properties([disableConcurrentBuilds()])

  try {
    // ===== Vars =====
    def project        = "fork-okta-spring-boot-sample"   // tên image/app
    def dockerRepo     = "192.168.137.128:18080"          // registry nội bộ (Harbor)
    def imagePrefix    = "ci"
    def dockerFile     = "Dockerfile"
    def imageName      = "${dockerRepo}/${imagePrefix}/${project}"
    def buildNumber    = env.BUILD_NUMBER
    def branchName  = env.BRANCH_NAME ?: "main"

    // K8s
    def k8sProjectName = "fork-okta-spring-boot-sample"   // tên Deployment & container trong K8s
    def namespace      = "default"

    // Nexus & Registry
    def NEXUS_MIRROR   = "http://192.168.137.128:8081/repository/maven-central/"

    stage('Workspace Clearing') { cleanWs() }

    stage('Checkout code') {
      checkout scm
      if (env.BRANCH_NAME) {
        sh "git fetch --all --prune && git checkout -B ${branchName} origin/${branchName} && git reset --hard origin/${branchName}"
      } else {
        echo "No BRANCH_NAME; using currently checked out commit."
      }
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

    stage('Build (Maven Wrapper)') {
      sh '''
        set -e
        java -version || true
		chmod +x mvnw
        ./mvnw -v
        ./mvnw -U -B -s .mvn/settings-nexus.xml -DskipTests clean package
      '''
      archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
    }

    stage('Docker Build') {
      sh "docker build -t ${imageName}:${branchName} -f ${dockerFile} ."
    }

    stage('Push Image') {
      withCredentials([usernamePassword(credentialsId: dockerCredId, usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
        sh """
          docker push ${imageName}:${branchName}
          docker tag  ${imageName}:${branchName} ${imageName}:${branchName}-build-${buildNumber}
          docker push ${imageName}:${branchName}-build-${buildNumber}
          docker logout ${dockerRepo} || true
        """
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
