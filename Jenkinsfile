#!groovy
@Library('ml-shared-lib@ng-lib') _

def upload(target_path) {
    sh "curl -u \$JFROG_USERNAME:\$JFROG_PASSWORD -X PUT -T build/${env.ARTIFACT_PKGNAME} ${env.ARTIFACTORY_SERVER}/artifactory/${env.REPO_TARGET}/${target_path}/${env.ARTIFACT_PKGNAME}"
}

def publish_build() {
    withCredentials([usernamePassword(credentialsId: 'srv-ml-jkns', usernameVariable: 'JFROG_USERNAME', passwordVariable: 'JFROG_PASSWORD')]) {
        if (env.BRANCH_NAME.startsWith("release")) {
            def config = parseConfig filePath: "build/${env.ARTIFACT_FILENAME}/default/app.conf"
            def versionHandler = parseVersion config['launcher']['version']
            // e.g. releases/4.4.x/4.4.3/file
            upload("releases/${versionHandler.getReleaseFolder()}/RC${env.BUILD_NUMBER}")
            upload("releases/${versionHandler.getReleaseFolder()}")
        } else {
            if (env.BRANCH_NAME == "master") {
                upload("builds/master/latest")
            }
            if (env.BRANCH_NAME == "master_py2") {
                upload("builds/master_py2/latest")
            }
            if (env.BRANCH_NAME == "master" || env.BRANCH_NAME == "master_py2" || params.PUBLISH) {
                upload("builds/${env.BRANCH_NAME}/${env.BUILD_NUMBER}")
            }
        }
    }
}

pipeline {
    agent none
    parameters {
        booleanParam(name: 'BUILD_LINUX', defaultValue: true, description: 'build PSC linux app')
        booleanParam(name: 'BUILD_OSX', defaultValue: true, description: 'build PSC OSX app')
        booleanParam(name: 'BUILD_WINDOWS', defaultValue: false, description: 'build PSC windows app')
        booleanParam(name: 'PUBLISH', defaultValue: false, description: 'whether to publish to Artifactory')
    }
    options {
        buildDiscarder(logRotator(daysToKeepStr: '10'))
        ansiColor('xterm')
        timestamps()
    }

    stages {
        /*
         *  Publish the built image to Artifactory docker registry
         */
        stage("Build PSC Packages") {
            environment {
                REPO_TARGET = "Solutions/Machine-Learning/app-sasp"
            }
            parallel {
                stage('PSC linux') {
                    agent { label 'linux' }
                    when {
                        beforeAgent true
                        expression { return params.BUILD_LINUX }
                    }
                    environment {
                        ARTIFACT_FILENAME = "Splunk_SA_Scientific_Python_linux_x86_64"
                        ARTIFACT_PKGNAME  = "${env.ARTIFACT_FILENAME}.tgz"
                    }
                    steps {
                        script {
                            sh 'bash repack.sh'
                            sh 'bash build.sh'
                            publish_build()
                        }
                    }
                }
                stage('PSC OSX'){
                    agent { label 'osx' }
                    when {
                        beforeAgent true
                        expression { return params.BUILD_OSX }
                    }
                    environment {
                        ARTIFACT_FILENAME = "Splunk_SA_Scientific_Python_darwin_x86_64"
                        ARTIFACT_PKGNAME  = "${env.ARTIFACT_FILENAME}.tgz"
                    }
                    steps {
                        script {
                            sh 'bash repack.sh'
                            sh 'bash build.sh'
                            publish_build()
                        }
                    }
                }
            }
        }
    }
}
