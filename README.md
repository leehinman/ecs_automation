# ecs_automation
Tools to ease updating of ECS version in integrations repo

## Flow

1. Use `get_candidates.sh` to get a list of package directories to
   update.
     ``` bash
     ./get_candidates.sh ~/src/integrations elastic/security-external-integrations > candidates.txt
     ```
2. Look through the list to verify packages, maybe use `split` to
   break list up into smaller chunks.  Updating lots of packages at
   once isn't advisable because you are competing with other package
   changes.
3. Create a git branch for your changes
4. Run `update_ecs_version.sh`
     ``` bash
     ./update_ecs_version.sh '8.4.0' 'git@v8.4.0-rc1' ./candidates.txt > updates.ndjson
     ```
5. Verify the changes look good & that the draft PR description & labels are
   correct.
6. Run `update_with_pr.sh` to update the changelog and manifest as
   well as generate new expected files and README files.
     ``` bash
     ./update_with_pr.sh updates.ndjson > results.txt
     ```
7. Verify that CI passes all tests
8. Take PR out of Draft and mark ready for review.

## Reasoning

1. git branching strategies are personal, you are responsible for
   making the branch and deleting when you are done
2. Why a two step process? Originally the PR step was manual, but it
   turns out to be a nice spot to inspect the changes and make sure we
   are on the right track.
3. Why ndjson between the 2 scripts?  Nice way to pass along a group
   of variables.

## Possible Enhancements

1. Make running `update_with_pr.sh` more idempotent.  Changelog and
   Manifest shouldn't be updated again, but regenerating tests should
   happen.
2. Switch to yq to set `ecs.version` in `update_ecs_version.sh`.  The current perl
   one liner is fragile.  Only problem is yq reformats some of the larger
   pipelines resulting in a large diff.
     ``` bash
       yq -i e "(.processors[] | select(.set.field == \"ecs.version\") | .set.value) = \"${ECS_VERSION}\"" "$PIPELINE"
     ```

