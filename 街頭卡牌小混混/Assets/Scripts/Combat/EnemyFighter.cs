using System;
using UnityEngine;

namespace StreetCardBrawler.Combat
{
    [RequireComponent(typeof(Rigidbody2D))]
    [RequireComponent(typeof(BoxCollider2D))]
    public sealed class EnemyFighter : MonoBehaviour
    {
        public int maxHealth = 90;
        public int health = 90;
        public int attackDamage = 8;
        public float moveSpeed = 2.6f;
        public float attackRange = 1.25f;
        public float attackCooldown = 1.2f;
        public float hitStunDuration = 0.18f;
        public Transform playerTarget;
        public PlayerFighter player;

        public event Action EnemyDied;

        private Rigidbody2D body;
        private float attackTimer;
        private float stunTimer;
        private float aggressionMultiplier = 1f;
        private float tauntTimer;
        private bool dead;

        public bool IsDead => dead;

        private void Awake()
        {
            body = GetComponent<Rigidbody2D>();
            health = Mathf.Clamp(health, 1, maxHealth);
        }

        private void Update()
        {
            if (dead || playerTarget == null || player == null || player.IsDead)
            {
                body.linearVelocity = Vector2.zero;
                return;
            }

            if (tauntTimer > 0f)
            {
                tauntTimer -= Time.deltaTime;
                if (tauntTimer <= 0f) aggressionMultiplier = 1f;
            }

            if (stunTimer > 0f)
            {
                stunTimer -= Time.deltaTime;
                body.linearVelocity = Vector2.zero;
                return;
            }

            attackTimer -= Time.deltaTime * aggressionMultiplier;
            float distance = Mathf.Abs(playerTarget.position.x - transform.position.x);
            float direction = Mathf.Sign(playerTarget.position.x - transform.position.x);

            if (distance > attackRange)
            {
                body.linearVelocity = new Vector2(direction * moveSpeed * aggressionMultiplier, body.linearVelocity.y);
            }
            else
            {
                body.linearVelocity = Vector2.zero;
                if (attackTimer <= 0f)
                {
                    attackTimer = attackCooldown;
                    player.TakeDamage(attackDamage);
                }
            }
        }

        public void TakeDamage(int amount)
        {
            if (dead) return;
            health = Mathf.Max(0, health - Mathf.Max(0, amount));
            stunTimer = hitStunDuration;
            if (health == 0)
            {
                dead = true;
                body.linearVelocity = Vector2.zero;
                EnemyDied?.Invoke();
            }
        }

        public void ApplyTaunt(float duration)
        {
            tauntTimer = Mathf.Max(tauntTimer, duration);
            aggressionMultiplier = 1.75f;
        }
    }
}
