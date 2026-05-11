using System;
using UnityEngine;

namespace StreetCardBrawler.Combat
{
    [RequireComponent(typeof(Rigidbody2D))]
    [RequireComponent(typeof(BoxCollider2D))]
    public sealed class PlayerFighter : MonoBehaviour
    {
        public int maxHealth = 100;
        public int health = 100;
        public int maxEnergy = 5;
        public int energy = 3;
        public float energyRegenPerSecond = 0.75f;
        public float moveSpeed = 5f;
        public CardDeckController deckController;

        public event Action PlayerDied;

        private Rigidbody2D body;
        private float energyAccumulator;
        private float blockTimer;
        private float incomingDamageMultiplier = 1f;
        private bool dead;

        public bool IsDead => dead;
        public bool IsBlocking => blockTimer > 0f;
        public float FacingSign { get; private set; } = 1f;

        private void Awake()
        {
            body = GetComponent<Rigidbody2D>();
            health = Mathf.Clamp(health, 1, maxHealth);
            energy = Mathf.Clamp(energy, 0, maxEnergy);
        }

        private void Update()
        {
            if (dead)
            {
                body.linearVelocity = Vector2.zero;
                return;
            }

            float input = Input.GetAxisRaw("Horizontal");
            if (Mathf.Abs(input) > 0.01f)
            {
                FacingSign = Mathf.Sign(input);
            }

            body.linearVelocity = new Vector2(input * moveSpeed, body.linearVelocity.y);

            energyAccumulator += energyRegenPerSecond * Time.deltaTime;
            if (energyAccumulator >= 1f)
            {
                int gained = Mathf.FloorToInt(energyAccumulator);
                energyAccumulator -= gained;
                AddEnergy(gained);
            }

            if (blockTimer > 0f)
            {
                blockTimer -= Time.deltaTime;
                if (blockTimer <= 0f)
                {
                    incomingDamageMultiplier = 1f;
                }
            }

            if (deckController != null)
            {
                if (Input.GetKeyDown(KeyCode.Alpha1)) deckController.TryPlayCard(0);
                if (Input.GetKeyDown(KeyCode.Alpha2)) deckController.TryPlayCard(1);
                if (Input.GetKeyDown(KeyCode.Alpha3)) deckController.TryPlayCard(2);
            }
        }

        public bool SpendEnergy(int amount)
        {
            if (amount <= 0) return true;
            if (energy < amount) return false;
            energy -= amount;
            return true;
        }

        public void AddEnergy(int amount)
        {
            energy = Mathf.Clamp(energy + amount, 0, maxEnergy);
        }

        public void ApplyBlock(float duration, float damageMultiplier)
        {
            blockTimer = Mathf.Max(blockTimer, duration);
            incomingDamageMultiplier = Mathf.Clamp(damageMultiplier, 0.05f, 1f);
        }

        public void DashForward(float distance)
        {
            transform.position += new Vector3(FacingSign * distance, 0f, 0f);
        }

        public void TakeDamage(int amount)
        {
            if (dead) return;
            int finalDamage = Mathf.Max(1, Mathf.RoundToInt(amount * incomingDamageMultiplier));
            health = Mathf.Max(0, health - finalDamage);
            if (health == 0)
            {
                dead = true;
                body.linearVelocity = Vector2.zero;
                PlayerDied?.Invoke();
            }
        }
    }
}
