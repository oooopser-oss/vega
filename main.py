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
from autonomous_workflow import AutonomousContentWorkflow
from content_rewriter import ContentRewriter
from content_curator import ContentCurator

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

Config.init_directories()
scheduler = None
bot = None
content_manager = ContentManager()
workflow = None


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


@cli.group()
def workflow_cmds():
    pass


@workflow_cmds.command(name='discover')
@click.option('--min-relevance', type=float, default=0.5, help='Minimum relevance score (0-1)')
def discover(min_relevance):
    click.echo("🔍 Starting content discovery and curation...")
    global workflow
    workflow = AutonomousContentWorkflow()

    if not workflow.login():
        click.echo("✗ Failed to login")
        return

    result = workflow.discover_and_curate(min_relevance)
    click.echo(f"✓ Discovery complete!")
    click.echo(f"  Discovered channels: {result['discovered_channels']}")
    click.echo(f"  Curated posts: {result['curated_posts']}")
    click.echo(f"  Processed posts: {result['processed_posts']}")


@workflow_cmds.command(name='rewrite')
@click.option('--text', prompt='Text to rewrite', type=str)
@click.option('--style', default='engaging', type=click.Choice(['engaging', 'professional', 'casual']))
def rewrite(text, style):
    click.echo(f"✏️ Rewriting with style: {style}")
    rewriter = ContentRewriter()

    rewritten = rewriter.rewrite_caption(text, style=style)
    click.echo("\n📝 Original:")
    click.echo(text)
    click.echo("\n✨ Rewritten:")
    click.echo(rewritten)

    suggestions = rewriter.suggest_improvements(rewritten)
    if suggestions:
        click.echo("\n💡 Suggestions:")
        for suggestion in suggestions:
            click.echo(f"  • {suggestion}")


@workflow_cmds.command(name='match-images')
@click.option('--text', prompt='Caption text', type=str)
@click.option('--image-dir', default='content/images', help='Path to image directory')
@click.option('--limit', default=3, help='Number of matches to return')
def match_images(text, image_dir, limit):
    click.echo("🖼️ Matching images to caption...")
    matcher = ImageMatcher()

    matcher.load_image_library(image_dir)

    matching = matcher.find_matching_images(text, limit=limit)

    if matching:
        click.echo(f"\n✓ Found {len(matching)} matching images:")
        table_data = []
        for img in matching:
            table_data.append([
                img['filename'],
                f"{img['match_score']:.2f}",
                ', '.join(img['tags'][:3])
            ])
        headers = ['Filename', 'Match Score', 'Tags']
        click.echo(tabulate(table_data, headers=headers))
    else:
        click.echo("✗ No matching images found")


@workflow_cmds.command(name='full-workflow')
@click.option('--min-relevance', type=float, default=0.5)
@click.option('--auto-schedule', is_flag=True, default=True)
@click.option('--image-dir', default='content/images', help='Path to image directory')
def full_workflow_cmd(min_relevance, auto_schedule, image_dir):
    click.echo("🚀 Starting full autonomous workflow...")
    click.echo("  1. Discovering similar channels...")
    click.echo("  2. Curating relevant content...")
    click.echo("  3. Rewriting captions...")
    click.echo("  4. Matching images...")
    click.echo("  5. Scheduling posts...")

    global workflow
    workflow = AutonomousContentWorkflow()

    if not workflow.login():
        click.echo("✗ Failed to login")
        return

    workflow.load_image_library(image_dir)

    result = workflow.full_workflow(min_relevance, auto_schedule)

    click.echo("\n✓ Workflow complete!")
    report = workflow.get_workflow_report()
    click.echo(json.dumps(report, indent=2))


@workflow_cmds.command(name='report')
def workflow_report():
    global workflow
    if not workflow:
        workflow = AutonomousContentWorkflow()

    report = workflow.get_workflow_report()
    click.echo(json.dumps(report, indent=2))


if __name__ == '__main__':
    cli()
