BUILD_HASH=$(git rev-parse --short HEAD)
if [[ -z "$CI" ]]; then
    echo "[WARNING] Tsk tsk tsk, not on CI, you're on your own"
else
    if [[ -z "$ARTIFACTORY_TARGET" ]]; then
        echo "Please set ARTIFACTORY_TARGET"
        exit 1
    fi
    if [[ "$CI_COMMIT_REF_NAME" == "master" ]]; then
        # publish master
        TARGET_FOLDER="$ARTIFACTORY_TARGET/builds/master"
        jfrog rt u "build/*.tgz" "$TARGET_FOLDER/$BUILD_HASH/" --build-name "PSC_master" --build-number "$CI_PIPELINE_IID" --fail-no-op
        jfrog rt u "build/*.tgz" "$TARGET_FOLDER/latest/" --sync-deletes="$TARGET_FOLDER/latest/" --quiet --fail-no-op
        jfrog rt bdi "PSC_master" --max-builds=10
        echo "Builds are available at:"
        echo "$ARTIFACTORY_URL/$TARGET_FOLDER/$BUILD_HASH"
        echo "$ARTIFACTORY_URL/$TARGET_FOLDER/latest"
    elif [[ "$CI_COMMIT_REF_NAME" == "$VERSION" ]]; then
        # publish the tag
        TARGET_FOLDER="$ARTIFACTORY_TARGET/releases/${VERSION%.*}.x/$VERSION"
        jfrog rt u "build/*.tgz" "$TARGET_FOLDER/" --sync-deletes="$TARGET_FOLDER/${APP_NAME}_*.tgz" --quiet --fail-no-op
        jfrog rt u "build/*.tgz" "$TARGET_FOLDER/$BUILD_HASH/" --fail-no-op
        echo "Builds are available at:"
        echo "$ARTIFACTORY_URL/$TARGET_FOLDER"
    else
        if [[ -z "$CI_MERGE_REQUEST_IID" || "$CI_MERGE_REQUEST_IID" == " " ]]; then
          echo "Merge Request ID is empty : $CI_MERGE_REQUEST_IID"
          echo "[ERROR] Publish only master branch, merge_requests and tags, tag needs to match build script version too"
        else
          TARGET_FOLDER="$ARTIFACTORY_TARGET/builds/merge_requests/MR$CI_MERGE_REQUEST_IID"
          jfrog rt u "build/*.tgz" "$TARGET_FOLDER/" --sync-deletes="$TARGET_FOLDER/${APP_NAME}_*.tgz" --quiet --fail-no-op
          echo "Builds are available at:"
          echo "$ARTIFACTORY_URL/$TARGET_FOLDER"
        fi
    fi
fi

