#!/usr/bin/env python3
import os
import sys
import json
import click
import logging
from pathlib import Path
from datetime import datetime
from tabulate import tabulate
from config import Config
from scheduler import BotScheduler
from content_manager import ContentManager
from instagram_bot import InstagramBot

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

Config.init_directories()
scheduler = None
bot = None
content_manager = ContentManager()


@click.group()
def cli():
    pass


@cli.command()
@click.option('--username', prompt='Instagram username', hide_input=False)
@click.option('--password', prompt='Instagram password', hide_input=True)
def setup(username, password):
    with open('.env', 'a') as f:
        f.write(f'\nINSTAGRAM_USERNAME={username}\n')
        f.write(f'INSTAGRAM_PASSWORD={password}\n')
    click.echo("✓ Credentials saved to .env file")


@cli.command()
def start():
    global scheduler
    click.echo("🤖 Starting Instagram bot...")
    scheduler = BotScheduler()
    if scheduler.start():
        click.echo("✓ Bot started successfully!")
        try:
            while True:
                import time
                time.sleep(1)
        except KeyboardInterrupt:
            click.echo("\n⏹ Shutting down...")
            scheduler.stop()
    else:
        click.echo("✗ Failed to start bot")
        sys.exit(1)


@cli.command()
def status():
    bot_instance = InstagramBot()
    if bot_instance.login():
        status_info = {
            'is_running': scheduler.is_running if scheduler else False,
            'account': bot_instance.get_account_info(),
            'daily_stats': bot_instance.get_stats(),
            'content_stats': content_manager.get_stats()
        }
        click.echo(json.dumps(status_info, indent=2))
        bot_instance.logout()
    else:
        click.echo("✗ Failed to login")


@cli.group()
def content():
    pass


@content.command()
@click.option('--image', prompt='Path to image', type=click.Path(exists=True))
@click.option('--caption', prompt='Post caption')
@click.option('--schedule-time', default=None, help='Scheduled time (HH:MM)')
def add(image, caption, schedule_time):
    post = content_manager.add_post(image, caption, schedule_time)
    click.echo(f"✓ Post #{post['id']} added successfully!")
    click.echo(f"  Caption: {caption[:50]}...")
    if schedule_time:
        click.echo(f"  Scheduled: {schedule_time}")


@content.command()
def list():
    posts = content_manager.get_all_posts()
    if not posts:
        click.echo("No posts found")
        return

    table_data = []
    for post in posts:
        status = '✓ Posted' if post['posted'] else '⏳ Pending'
        table_data.append([
            post['id'],
            post['caption'][:40] + '...' if len(post['caption']) > 40 else post['caption'],
            status,
            post['scheduled_time'] or 'N/A'
        ])

    headers = ['ID', 'Caption', 'Status', 'Scheduled Time']
    click.echo(tabulate(table_data, headers=headers))
    click.echo(f"\nTotal: {len(posts)} | Posted: {len([p for p in posts if p['posted']])} | Pending: {len([p for p in posts if not p['posted']])}")


@content.command()
@click.option('--post-id', type=int, prompt='Post ID to delete')
def delete(post_id):
    if content_manager.delete_post(post_id):
        click.echo(f"✓ Post #{post_id} deleted")
    else:
        click.echo(f"✗ Post #{post_id} not found")


@content.command()
def stats():
    stats = content_manager.get_stats()
    click.echo(f"Total Posts: {stats['total_posts']}")
    click.echo(f"Posted: {stats['posted']}")
    click.echo(f"Pending: {stats['pending']}")


@cli.group()
def hashtags():
    pass


@hashtags.command()
@click.option('--hashtags', prompt='Hashtags (comma-separated)')
def set(hashtags):
    with open('.env', 'a') as f:
        f.write(f'\nTARGET_HASHTAGS={hashtags}\n')
    click.echo("✓ Target hashtags saved")


@cli.group()
def accounts():
    pass


@accounts.command()
@click.option('--accounts', prompt='Target accounts (comma-separated)')
def set(accounts):
    with open('.env', 'a') as f:
        f.write(f'\nTARGET_ACCOUNTS={accounts}\n')
    click.echo("✓ Target accounts saved")


@cli.command()
@click.option('--limit', type=int, default=10)
def like(limit):
    bot_instance = InstagramBot()
    if bot_instance.login():
        liked = bot_instance.like_posts_by_hashtags()
        click.echo(f"✓ Liked {liked} posts")
        bot_instance.logout()
    else:
        click.echo("✗ Failed to login")


@cli.command()
@click.option('--username', prompt='Username to follow from')
@click.option('--amount', type=int, default=10)
def follow(username, amount):
    bot_instance = InstagramBot()
    if bot_instance.login():
        followed = bot_instance.follow_user_followers(username, amount)
        click.echo(f"✓ Followed {followed} users from @{username}")
        bot_instance.logout()
    else:
        click.echo("✗ Failed to login")


if __name__ == '__main__':
    cli()
