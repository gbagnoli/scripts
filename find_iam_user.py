#!/usr/bin/env python
# Find the IAM username belonging to the TARGET_ACCESS_KEY

# Requirements:
#
# Environmental variables:
# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
# python:
# boto

import argparse
import sys
import boto.iam


def parse_args(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument('key', help='Key to search')
    args = p.parse_args(argv)
    return args.key


def main(argv=None):
    key = parse_args(argv)
    iam = boto.connect_iam()
    users = iam.get_all_users('/')['list_users_response']['list_users_result']['users']

    for user in users:
        for key_result in iam.get_all_access_keys(user['user_name'])['list_access_keys_response']['list_access_keys_result']['access_key_metadata']:
            aws_access_key = key_result['access_key_id']
            if aws_access_key == key:
                print('Key "%s" belongs to user: %s' % (key, user['user_name']))
                return 0
    else:
        print('Did not find access key "%s" in %d IAM users' % (key, len(users)))
        return 1


if __name__ == '__main__':
    sys.exit(main())
