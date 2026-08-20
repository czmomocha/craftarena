/**
 * 内网端口分配。
 *
 * 宪法第二十二条：Godot MatchServer 使用内网临时端口，不直接暴露公网。
 * 端口只在 MatchHost 内部记账，任何对外暴露都必须经过网关。
 */
export class PortAllocator {
	readonly #min: number;
	readonly #max: number;
	readonly #inUse = new Set<number>();
	#cursor: number;

	constructor(min: number, max: number) {
		if (!Number.isInteger(min) || !Number.isInteger(max) || min < 1024 || max > 65535 || min > max) {
			throw new Error(`invalid port range: [${min}, ${max}]`);
		}

		this.#min = min;
		this.#max = max;
		this.#cursor = min;
	}

	/**
	 * 从上次分配的位置往后找，而不是每次从头扫。
	 * 从头扫会让刚释放的端口立刻被复用，撞上前一场对局的在途 UDP/TCP 报文。
	 */
	allocate(): number {
		const capacity = this.#max - this.#min + 1;

		for (let attempt = 0; attempt < capacity; attempt += 1) {
			const candidate = this.#cursor;
			this.#cursor = candidate >= this.#max ? this.#min : candidate + 1;

			if (!this.#inUse.has(candidate)) {
				this.#inUse.add(candidate);
				return candidate;
			}
		}

		throw new Error(`no free port in range [${this.#min}, ${this.#max}]`);
	}

	release(port: number): void {
		this.#inUse.delete(port);
	}

	get inUseCount(): number {
		return this.#inUse.size;
	}
}
